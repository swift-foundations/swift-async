import Async
import Testing

private actor `Lifecycle Flag` {
    private(set) var isSet = false

    func set() {
        isSet = true
    }
}

extension `Lifecycle Flag` {

    func waitUntilSet(attempts: Int = 200, interval: Duration = .milliseconds(10)) async -> Bool {
        for _ in 0..<attempts {
            if isSet { return true }
            try? await Task.sleep(for: interval)
        }
        return isSet
    }
}

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

    @Test(.timeLimit(.minutes(2)))
    func `merge resumes a suspended consumer instead of hanging when its task is cancelled`()
        async throws
    {

        let (rawA, _) = AsyncStream<Int>.makeStream()
        let (rawB, _) = AsyncStream<Int>.makeStream()
        let merged = Async.Stream.merge(Async.Stream(rawA), Async.Stream(rawB))

        let consumer = Task {
            for await _ in merged {}
        }

        try await Task.sleep(for: .milliseconds(50))
        consumer.cancel()

        let finished = await withDeadline { await consumer.value }
        #expect(finished != nil)
    }

    @Test(.timeLimit(.minutes(2)))
    func `replay resumes a suspended consumer instead of hanging when its task is cancelled`()
        async throws
    {

        let (raw, _) = AsyncStream<Int>.makeStream()
        let replayed = Async.Stream(raw).replay(bufferSize: 4)

        let consumer = Task {
            for await _ in replayed {}
        }

        try await Task.sleep(for: .milliseconds(50))
        consumer.cancel()

        let finished = await withDeadline { await consumer.value }
        #expect(finished != nil)
    }

    @Test(.timeLimit(.minutes(2)))
    func `merge cancels both producer tasks when its iterator is dropped without exhausting`()
        async throws
    {
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

        }

        let sawA = await flagA.waitUntilSet()
        let sawB = await flagB.waitUntilSet()

        #expect(sawA)
        #expect(sawB)
    }

    @Test(.timeLimit(.minutes(2)))
    func `share cancels upstream forwarding once the shared stream is totally abandoned`()
        async throws
    {
        let flag = `Lifecycle Flag`()
        let (raw, continuation) = AsyncStream<Int>.makeStream()
        continuation.onTermination = { _ in Task { await flag.set() } }

        do {
            let shared = Async.Stream(raw).share()
            continuation.yield(1)
            let iterator = shared.makeAsyncIterator()
            _ = await iterator.next()

        }

        #expect(await flag.waitUntilSet())
    }

    @Test(.timeLimit(.minutes(2)))
    func `replay cancels upstream forwarding once the replay stream is totally abandoned`()
        async throws
    {
        let flag = `Lifecycle Flag`()
        let (raw, continuation) = AsyncStream<Int>.makeStream()
        continuation.onTermination = { _ in Task { await flag.set() } }

        do {
            let replayed = Async.Stream(raw).replay(bufferSize: 4)
            continuation.yield(1)
            let iterator = replayed.makeAsyncIterator()
            _ = await iterator.next()

        }

        #expect(await flag.waitUntilSet())
    }

    @Test(.timeLimit(.minutes(2)))
    func `replay subscription count returns to zero after N consumers churn through`() async throws
    {
        let (replayed, subscriptionCount) = Async.Stream.from([1, 2, 3, 4, 5]).replayForTesting(
            bufferSize: 4
        )

        for _ in 0..<10 {
            let iterator = replayed.makeAsyncIterator()
            _ = await iterator.next()

        }

        var finalCount = -1
        for _ in 0..<200 {
            finalCount = await subscriptionCount()
            if finalCount == 0 { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(finalCount == 0)
    }

    @Test(.timeLimit(.minutes(2)))
    func `replay preserves per-subscriber delivery order under contention`() async throws {
        let count = 500
        let upstream = Async.Stream.from(Array(0..<count))
        let replayed = upstream.replay(bufferSize: 8)

        var results: [Int] = []
        for await value in replayed {
            results.append(value)
        }

        #expect(results == Array(0..<count))
    }

    @Test(.timeLimit(.minutes(2)))
    func `replay delivers a fast pre-subscribed burst in strict send order with no drops`()
        async throws
    {
        let elementCount = 2_000
        let trialCount = 5

        for trial in 0..<trialCount {
            let (raw, continuation) = AsyncStream<Int>.makeStream()

            let (replayed, subscriptionCount) = Async.Stream(raw).replayForTesting(
                bufferSize: elementCount
            )

            let consumer = Task<[Int], Never> {
                var results: [Int] = []
                results.reserveCapacity(elementCount)
                for await value in replayed {
                    results.append(value)
                }
                return results
            }

            for _ in 0..<200 {
                if await subscriptionCount() >= 1 { break }
                try? await Task.sleep(for: .milliseconds(5))
            }

            for value in 0..<elementCount {
                continuation.yield(value)
            }
            continuation.finish()

            let results = await withDeadline(.seconds(60)) { await consumer.value }
            let expected = Array(0..<elementCount)

            if let results {
                let firstBad = (0..<Swift.min(results.count, expected.count)).first {
                    results[$0] != expected[$0]
                }
                let detail =
                    firstBad.map {
                        " (first divergence @\($0): \(results[$0]) != \(expected[$0]))"
                    }
                    ?? " (length mismatch)"
                let message =
                    "trial \(trial): got \(results.count)/\(expected.count) elements" + detail
                #expect(results == expected, Comment(rawValue: message))
            } else {
                #expect(
                    Bool(false),
                    Comment(rawValue: "trial \(trial): consumer did not finish within the deadline")
                )
            }
        }
    }
}
