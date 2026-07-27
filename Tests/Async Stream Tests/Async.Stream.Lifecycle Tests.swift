// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Async
import Testing

// MARK: - Fable-448 regression coverage: F-001, F-002, F-003, F-004
//
// Cancellation, resource-lifetime, and ordering fixes for `merge`, `replay`,
// and `share` — see O/remediation/swift-async/REPORT.md for the full
// finding -> fix -> commit mapping.

/// Tiny actor used across these tests to observe events (termination,
/// completion) from inside a `@Sendable` closure without a data race.
private actor `Lifecycle Flag` {
    private(set) var isSet = false

    func set() {
        isSet = true
    }
}

extension `Lifecycle Flag` {
    /// Polls `isSet` with a short sleep between checks, up to `attempts`
    /// times. Used instead of a single `try await Task.sleep` so these tests
    /// resolve as soon as the observed event actually happens, rather than
    /// always paying a fixed worst-case delay.
    func waitUntilSet(attempts: Int = 200, interval: Duration = .milliseconds(10)) async -> Bool {
        for _ in 0..<attempts {
            if isSet { return true }
            try? await Task.sleep(for: interval)
        }
        return isSet
    }
}

/// Awaits `task.value` with a hard deadline, returning `nil` on timeout
/// instead of hanging forever.
///
/// `@Test(.timeLimit(...))` cancels the *test function's own* task when the
/// limit is exceeded — it does NOT reach into a separately spawned
/// unstructured `Task` and force it to finish, and `Task<Void, Never>.value`
/// does not itself observe ambient cancellation (there is no throwing
/// overload to interrupt). So awaiting a hung child task's `.value` directly
/// would hang the whole test binary indefinitely pre-fix, `.timeLimit` or
/// not. Racing it against an explicit timeout task, and taking whichever
/// finishes first, is what actually bounds the wait.
private func withDeadline<T: Sendable>(
    _ deadline: Duration = .seconds(15),
    _ operation: @escaping @Sendable () async -> T
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await operation() }
        group.addTask {
            try? await Task.sleep(for: deadline)
            return nil
        }
        let first = await group.next()!
        group.cancelAll()
        return first
    }
}

extension `Async.Stream Tests`.`Edge Case` {

    // MARK: F-001 — continuation-cancellation hangs (blocker)

    @Test(.timeLimit(.minutes(2)))
    func `merge resumes a suspended consumer instead of hanging when its task is cancelled`() async throws {
        // Two `AsyncStream`s whose continuations are never used: they never
        // yield and never finish, so `merge`'s only path to completion is
        // consumer-task cancellation — exactly what this test exercises.
        // (Deliberately not `Async.Stream<Int>.never`: that type's own
        // `Task.sleep(for: .seconds(Int64.max))` crashes the process with a
        // "Not enough bits to represent the passed value" fatal error once
        // the sleep actually starts and then observes cancellation — a
        // separate, pre-existing bug outside this brief's scope, flagged
        // separately.)
        let (rawA, _) = AsyncStream<Int>.makeStream()
        let (rawB, _) = AsyncStream<Int>.makeStream()
        let merged = Async.Stream.merge(Async.Stream(rawA), Async.Stream(rawB))

        let consumer = Task {
            for await _ in merged {}
        }

        // Give the consumer a moment to actually suspend inside
        // `Merge.State.receive()`'s continuation wait.
        try await Task.sleep(for: .milliseconds(50))
        consumer.cancel()

        // Pre-fix: `receive()`'s bare `withCheckedContinuation` never
        // observes cancellation, so `consumer` never finishes — `withDeadline`
        // times out and returns `nil` (FAILING). Post-fix,
        // `withTaskCancellationHandler` resumes the continuation with `nil`
        // promptly, well inside the deadline (PASSING).
        let finished = await withDeadline { await consumer.value }
        #expect(finished != nil)
    }

    @Test(.timeLimit(.minutes(2)))
    func `replay resumes a suspended consumer instead of hanging when its task is cancelled`() async throws {
        // See the merge test above for why this uses a never-yielding
        // `AsyncStream` instead of `Async.Stream<Int>.never`.
        let (raw, _) = AsyncStream<Int>.makeStream()
        let replayed = Async.Stream(raw).replay(bufferSize: 4)

        let consumer = Task {
            for await _ in replayed {}
        }

        // Give the consumer a moment to actually suspend inside
        // `Replay.Subscription.next()`'s continuation wait.
        try await Task.sleep(for: .milliseconds(50))
        consumer.cancel()

        // Pre-fix: hangs forever (see the merge test above for the same
        // mechanism and why `withDeadline` — not `.timeLimit` alone — is
        // what bounds this); post-fix: resumes promptly.
        let finished = await withDeadline { await consumer.value }
        #expect(finished != nil)
    }

    // MARK: F-002 — eager, never-cancelled forwarding / producer tasks

    @Test(.timeLimit(.minutes(2)))
    func `merge cancels both producer tasks when its iterator is dropped without exhausting`() async throws {
        let flagA = `Lifecycle Flag`()
        let flagB = `Lifecycle Flag`()

        let (rawA, continuationA) = AsyncStream<Int>.makeStream()
        continuationA.onTermination = { _ in Task { await flagA.set() } }
        let (rawB, continuationB) = AsyncStream<Int>.makeStream()
        continuationB.onTermination = { _ in Task { await flagB.set() } }

        do {
            let merged = Async.Stream.merge(Async.Stream(rawA), Async.Stream(rawB))
            continuationA.yield(1)
            let iterator = merged.makeAsyncIterator()
            _ = await iterator.next()
            // `merged`/`iterator` (and therefore the Merge.Cursor holding
            // both producer tasks) go out of scope at the closing brace
            // below — without ever exhausting the sequence and without any
            // enclosing Task being cancelled. Old code never cancelled
            // task1/task2 on this path.
        }

        let sawA = await flagA.waitUntilSet()
        let sawB = await flagB.waitUntilSet()

        #expect(sawA)
        #expect(sawB)
    }

    @Test(.timeLimit(.minutes(2)))
    func `share cancels upstream forwarding once the shared stream is totally abandoned`() async throws {
        let flag = `Lifecycle Flag`()
        let (raw, continuation) = AsyncStream<Int>.makeStream()
        continuation.onTermination = { _ in Task { await flag.set() } }

        do {
            let shared = Async.Stream(raw).share()
            continuation.yield(1)
            let iterator = shared.makeAsyncIterator()
            _ = await iterator.next()
            // `shared`/`iterator` (and therefore `Share.State`'s forwarding
            // task) go out of scope here. Pre-fix, the forwarding task had no
            // retained handle anywhere and could never be cancelled, so
            // `onTermination` would never fire.
        }

        #expect(await flag.waitUntilSet())
    }

    @Test(.timeLimit(.minutes(2)))
    func `replay cancels upstream forwarding once the replay stream is totally abandoned`() async throws {
        let flag = `Lifecycle Flag`()
        let (raw, continuation) = AsyncStream<Int>.makeStream()
        continuation.onTermination = { _ in Task { await flag.set() } }

        do {
            let replayed = Async.Stream(raw).replay(bufferSize: 4)
            continuation.yield(1)
            let iterator = replayed.makeAsyncIterator()
            _ = await iterator.next()
            // `replayed`/`iterator` (and therefore `Replay.Connection`'s
            // forwarding task) go out of scope here. Pre-fix, the forwarding
            // task was a bare fire-and-forget `Task` with no retained handle
            // anywhere.
        }

        #expect(await flag.waitUntilSet())
    }

    // MARK: F-003 — dead unsubscribe / unbounded subscription accumulation

    @Test(.timeLimit(.minutes(2)))
    func `replay subscription count returns to zero after N consumers churn through`() async throws {
        let (replayed, subscriptionCount) = Async.Stream.from([1, 2, 3, 4, 5]).replayForTesting(bufferSize: 4)

        for _ in 0..<10 {
            let iterator = replayed.makeAsyncIterator()
            _ = await iterator.next()
            // `iterator` (and its Cursor) is dropped at the end of each loop
            // iteration's scope, one consumer at a time.
        }

        var finalCount = -1
        for _ in 0..<200 {
            finalCount = await subscriptionCount()
            if finalCount == 0 { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        // Pre-fix: `State.unsubscribe(_:)` was dead code — nothing ever
        // called it — so all 10 abandoned subscriptions stay registered
        // forever and this never reaches zero.
        #expect(finalCount == 0)
    }

    // MARK: F-004 — unordered fire-and-forget delivery

    @Test(.timeLimit(.minutes(2)))
    func `replay preserves per-subscriber delivery order under contention`() async throws {
        let count = 500
        let upstream = Async.Stream.from(Array(0..<count))
        let replayed = upstream.replay(bufferSize: 8)

        var results: [Int] = []
        for await value in replayed {
            results.append(value)
        }

        // Pre-fix: `Subscription.receive(_:)` delivered each element via a
        // separately spawned, unstructured `Task { await _receive(element) }`
        // — Swift does not guarantee spawn order == actor-enqueue order for
        // concurrently created Tasks, so rapid back-to-back `send()` calls
        // could deliver elements out of order under scheduler contention.
        // (Whether this specific ordering race reproduces reliably in any
        // given run is inherently timing-dependent — see REPORT.md for how
        // its pre-fix evidence was captured.)
        #expect(results == Array(0..<count))
    }

    /// Stronger companion to the test above, targeting F-004's live-delivery
    /// path directly. Unlike that test it subscribes *before* any element is
    /// produced — via the `replayForTesting` subscription-count hook — so every
    /// element travels the live `State.send` -> `Subscription.receive` path
    /// (F-004's actual mechanism) rather than the late-subscriber ring
    /// backfill, then drives a large burst as fast as possible and asserts the
    /// consumer observes strict send order with no drops.
    ///
    /// Post-fix this is DETERMINISTIC: `send`/`finish` `await` the
    /// actor-isolated `receive`/`finish` inline in the single sequential
    /// producer loop — there is no unstructured Task in the delivery path at
    /// all — so delivery order equals send order and nothing is dropped, on
    /// every run. Pre-F-004 (`Subscription.receive`/`finish` each spawn an
    /// unstructured `Task { await _receive(element) }`), the same burst is a
    /// best-effort discriminator, NOT a guaranteed one: Swift does not
    /// guarantee spawn order == actor-enqueue order for concurrently created
    /// Tasks, so elements *can* be delivered reordered, or `finish` *can*
    /// resume the consumer with `nil` before pending deliveries run
    /// (truncation) — but whether that window opens on a given run is
    /// scheduler-dependent and does not reproduce reliably on a loaded machine.
    /// See `O/remediation/swift-async/REPORT.md` (d)/(g) for why a deterministic
    /// pre-fix repro is not reachable without injecting a controllable executor
    /// into the (approved, unmodified) fix source, and why the primary F-004
    /// evidence is the code-level soundness of the synchronous ordered-delivery
    /// fix plus the deterministic F-001/F-002/F-003 regressions.
    @Test(.timeLimit(.minutes(2)))
    func `replay delivers a fast pre-subscribed burst in strict send order with no drops`() async throws {
        let elementCount = 2_000
        let trialCount = 5

        for trial in 0..<trialCount {
            let (raw, continuation) = AsyncStream<Int>.makeStream()
            // Ring sized to hold the whole burst: this keeps the POST-FIX
            // assertion timing-independent (a consumer that registers late
            // still reconstructs the full ordered sequence from the ring
            // backfill, so the test cannot flake green->red under load), while
            // the pre-subscribe poll below still tries to hit the live
            // `send`->`receive` path that is F-004's actual mechanism.
            let (replayed, subscriptionCount) = Async.Stream(raw).replayForTesting(bufferSize: elementCount)

            let consumer = Task<[Int], Never> {
                var results: [Int] = []
                results.reserveCapacity(elementCount)
                for await value in replayed {
                    results.append(value)
                }
                return results
            }

            // Best-effort: wait for the consumer to register before producing,
            // so elements travel the live-delivery path (F-004's mechanism)
            // rather than the ring backfill. Correctness does not depend on
            // this succeeding — the full-size ring above covers the late case.
            for _ in 0..<200 {
                if await subscriptionCount() >= 1 { break }
                try? await Task.sleep(for: .milliseconds(5))
            }

            // Drive the whole burst as fast as possible, then finish.
            for value in 0..<elementCount {
                continuation.yield(value)
            }
            continuation.finish()

            // withDeadline guards against a pre-fix hang; post-fix the consumer
            // finishes well inside it.
            let results = await withDeadline(.seconds(60)) { await consumer.value }
            let expected = Array(0..<elementCount)

            if let results {
                let firstBad = zip(results, expected).enumerated().first { _, pair in pair.0 != pair.1 }?.offset
                let detail = firstBad.map { " (first divergence @\($0): \(results[$0]) != \(expected[$0]))" }
                    ?? " (length mismatch)"
                let message = "trial \(trial): got \(results.count)/\(expected.count) elements" + detail
                #expect(results == expected, Comment(rawValue: message))
            } else {
                #expect(Bool(false), Comment(rawValue: "trial \(trial): consumer did not finish within the deadline"))
            }
        }
    }
}
