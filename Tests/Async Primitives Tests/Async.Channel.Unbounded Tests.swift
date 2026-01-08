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

@Suite("Async.Channel.Unbounded")
struct UnboundedChannelTests {

    @Test("Send and receive single element")
    func sendReceiveSingleElement() async throws {
        let channel = Async.Channel.Unbounded<Int>()
        try channel.send(42)
        channel.close()
        let value = try await channel.receive()
        #expect(value == 42)
    }

    @Test("Send succeeds when channel is open")
    func sendSucceedsWhenOpen() throws {
        let channel = Async.Channel.Unbounded<Int>()
        try channel.send(42)
        channel.close()
    }

    @Test("Closed channel rejects send")
    func closedChannelRejectsSend() {
        let channel = Async.Channel.Unbounded<Int>()
        channel.close()
        #expect(throws: Async.Channel.Unbounded<Int>.Error.closed) {
            try channel.send(42)
        }
    }

    @Test("Receive returns nil after close and drain")
    func receiveReturnsNilAfterCloseAndDrain() async throws {
        let channel = Async.Channel.Unbounded<Int>()
        try channel.send(1)
        try channel.send(2)
        channel.close()

        let first = try await channel.receive()
        let second = try await channel.receive()
        let third = try await channel.receive()

        #expect(first == 1)
        #expect(second == 2)
        #expect(third == nil)
    }

    @Test("Try receive returns nil when empty")
    func tryReceiveReturnsNilWhenEmpty() {
        let channel = Async.Channel.Unbounded<Int>()
        let result = channel.receive.tryOne()
        #expect(result == nil)
    }

    @Test("Try receive returns element when available")
    func tryReceiveReturnsElement() throws {
        let channel = Async.Channel.Unbounded<Int>()
        try channel.send(42)
        let result = channel.receive.tryOne()
        #expect(result == 42)
    }

    @Test("Send batch elements")
    func sendBatch() async throws {
        let channel = Async.Channel.Unbounded<Int>()
        try channel.send(contentsOf: [1, 2, 3])
        channel.close()

        var received: [Int] = []
        while let value = try await channel.receive() {
            received.append(value)
        }
        #expect(received == [1, 2, 3])
    }

    @Test("isClosed reflects state")
    func isClosedReflectsState() {
        let channel = Async.Channel.Unbounded<Int>()
        #expect(channel.isClosed == false)
        channel.close()
        #expect(channel.isClosed == true)
    }

    @Test("Receive suspends until element available")
    func receiveSuspendsUntilElement() async throws {
        let channel = Async.Channel.Unbounded<Int>()

        // Start receive in background
        let receiveTask = Task {
            try await channel.receive()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Send element
        try channel.send(42)

        // Receive should complete with the element
        let result = try await receiveTask.value
        #expect(result == 42)
    }

    @Test("Receive resumes with nil on close")
    func receiveResumesOnClose() async throws {
        let channel = Async.Channel.Unbounded<Int>()

        // Start receive in background
        let receiveTask = Task {
            try await channel.receive()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Close channel
        channel.close()

        // Receive should complete with nil
        let result = try await receiveTask.value
        #expect(result == nil)
    }

    @Test("Multiple producers can send concurrently")
    func multipleProducers() async throws {
        let channel = Async.Channel.Unbounded<Int>()
        let count = 100

        // Launch multiple producer tasks
        await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    try channel.send(i)
                }
            }
        }

        channel.close()

        // Collect all received values
        var received: Set<Int> = []
        while let value = try await channel.receive() {
            received.insert(value)
        }

        // Should have received all values
        #expect(received.count == count)
        for i in 0..<count {
            #expect(received.contains(i))
        }
    }

    @Test("Cancellation throws cancelled error")
    func cancellationThrowsCancelled() async {
        let channel = Async.Channel.Unbounded<Int>()

        let receiveTask = Task {
            try await channel.receive()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Cancel the task
        receiveTask.cancel()

        // Should throw cancelled error
        do {
            _ = try await receiveTask.value
            Issue.record("Expected cancellation error")
        } catch let error as Async.Channel.Unbounded<Int>.Error {
            #expect(error == .cancelled)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Stress Tests

@Suite("Async.Channel.Unbounded.Stress")
struct UnboundedChannelStressTests {

    /// Yield multiple times to allow concurrent tasks to make progress.
    /// Replacement for Task.sleep - deterministic and not wall-clock dependent.
    private func yieldProgress(iterations: Int = 50) async {
        for _ in 0..<iterations {
            await Task.yield()
        }
    }

    @Test("Cancellation racing with send - no lost elements")
    func cancellationRacingWithSend() async throws {
        // Many receivers waiting, some get cancelled, some get elements.
        // No element should be lost (either delivered or buffered).
        // This tests the critical race where cancellation could "eat" elements.
        for round in 0..<50 {
            let channel = Async.Channel.Unbounded<Int>()
            let receiverCount = 10
            let elementCount = 5

            // Start receivers first (they will suspend)
            let receiverTasks = (0..<receiverCount).map { _ in
                Task {
                    try await channel.receive()
                }
            }

            // Yield to let receivers suspend (no wall-clock sleep)
            await yieldProgress()

            // Cancel half the receivers (deterministic: even indices)
            for i in stride(from: 0, to: receiverCount, by: 2) {
                receiverTasks[i].cancel()
            }

            // Send elements
            for i in 0..<elementCount {
                try channel.send(i)
            }

            // Close channel
            channel.close()

            // Collect results, distinguish between element/nil/cancelled
            var receivedElements: [Int] = []
            var cancelledCount = 0

            for task in receiverTasks {
                do {
                    if let value = try await task.value {
                        receivedElements.append(value)
                    }
                    // nil means closed with no element
                } catch let error as Async.Channel.Unbounded<Int>.Error {
                    // Only .cancelled is acceptable here
                    #expect(error == .cancelled, "Round \(round): Expected .cancelled, got \(error)")
                    cancelledCount += 1
                } catch {
                    Issue.record("Round \(round): Unexpected error type: \(error)")
                }
            }

            // At least one cancellation should have occurred
            #expect(cancelledCount > 0, "Round \(round): No cancellations observed")

            // Drain remaining buffer
            while let value = try await channel.receive() {
                receivedElements.append(value)
            }

            // All elements must be accounted for - no loss
            let receivedSet = Set(receivedElements)
            #expect(receivedSet.count == elementCount,
                "Round \(round): Expected \(elementCount) unique elements, got \(receivedSet.count)")

            #expect(receivedSet == Set(0..<elementCount),
                "Round \(round): Missing elements: expected \(Set(0..<elementCount)), got \(receivedSet)")
        }
    }

    @Test("Many waiters cancelling repeatedly")
    func manyWaitersCancellingRepeatedly() async throws {
        // Stress test: many tasks wait, cancel, repeat.
        // Tests O(n) cancellation removal under load.
        let channel = Async.Channel.Unbounded<Int>()
        let iterations = 100
        let waitersPerIteration = 20

        for _ in 0..<iterations {
            // Start waiters
            let waiters = (0..<waitersPerIteration).map { _ in
                Task {
                    try await channel.receive()
                }
            }

            // Yield to let them suspend
            await yieldProgress(iterations: 20)

            // Cancel all waiters
            for waiter in waiters {
                waiter.cancel()
            }

            // All should complete with .cancelled (no hang, no other errors)
            for waiter in waiters {
                do {
                    _ = try await waiter.value
                    // If we get here without error, task wasn't cancelled in time
                    // That's OK - we might have raced
                } catch let error as Async.Channel.Unbounded<Int>.Error {
                    // Only .cancelled is acceptable
                    #expect(error == .cancelled)
                } catch {
                    Issue.record("Unexpected error type: \(error)")
                }
            }
        }

        // Channel should still be functional after stress
        try channel.send(42)
        let value = try await channel.receive()
        #expect(value == 42)
    }

    @Test("Close racing with pending receivers - exact element accounting")
    func closeRacingWithPendingReceivers() async throws {
        // Many receivers waiting when close() is called.
        // With pre-buffered elements, exactly that many receivers get elements,
        // the rest get nil.
        for round in 0..<50 {
            let channel = Async.Channel.Unbounded<Int>()
            let receiverCount = 20
            let preBufferedCount = 5

            // Pre-buffer exactly 5 elements
            for i in 0..<preBufferedCount {
                try channel.send(i)
            }

            // Start many receivers
            let receiverTasks = (0..<receiverCount).map { _ in
                Task {
                    try await channel.receive()
                }
            }

            // Yield to let receivers start (some will get buffered elements immediately)
            await yieldProgress()

            // Close channel
            channel.close()

            // Collect results
            var receivedElements: [Int] = []
            var nilCount = 0

            for task in receiverTasks {
                do {
                    if let value = try await task.value {
                        receivedElements.append(value)
                    } else {
                        nilCount += 1
                    }
                } catch {
                    Issue.record("Round \(round): Unexpected error: \(error)")
                }
            }

            // Exact accounting: 5 elements, rest nil
            #expect(receivedElements.count == preBufferedCount,
                "Round \(round): Expected \(preBufferedCount) elements, got \(receivedElements.count)")

            #expect(Set(receivedElements) == Set(0..<preBufferedCount),
                "Round \(round): Wrong elements received: \(receivedElements)")

            #expect(nilCount == receiverCount - preBufferedCount,
                "Round \(round): Expected \(receiverCount - preBufferedCount) nils, got \(nilCount)")
        }
    }

    @Test("Send-receive-cancel interleaving - complete element delivery")
    func sendReceiveCancelInterleaving() async throws {
        // Concurrent send, receive, and cancel operations.
        // All elements must be delivered exactly once (no loss, no duplication).
        let channel = Async.Channel.Unbounded<Int>()
        let elementCount = 500
        let receivedElements = Async.Channel.Unbounded<Int>()

        await withTaskGroup(of: Void.self) { group in
            // Producer: send all elements
            group.addTask {
                for i in 0..<elementCount {
                    try? channel.send(i)
                    await Task.yield()
                }
                channel.close()
            }

            // Multiple consumers with deterministic cancellation schedule
            for consumerId in 0..<5 {
                group.addTask {
                    var attempt = 0
                    while true {
                        let receiveTask = Task {
                            try await channel.receive()
                        }

                        // Deterministic cancellation: cancel every 7th attempt for even consumers
                        let shouldCancel = consumerId % 2 == 0 && attempt % 7 == 3
                        if shouldCancel {
                            await Task.yield()
                            receiveTask.cancel()
                        }

                        do {
                            if let value = try await receiveTask.value {
                                try? receivedElements.send(value)
                            } else {
                                break // Channel closed
                            }
                        } catch let error as Async.Channel.Unbounded<Int>.Error {
                            #expect(error == .cancelled)
                            // Cancelled, continue trying
                        } catch {
                            Issue.record("Unexpected error: \(error)")
                            break
                        }
                        attempt += 1
                    }
                }
            }
        }

        receivedElements.close()

        // Collect all received elements
        var received: [Int] = []
        while let value = try await receivedElements.receive() {
            received.append(value)
        }

        // No duplicates
        let receivedSet = Set(received)
        #expect(received.count == receivedSet.count,
            "Duplicate elements detected: \(received.count) received, \(receivedSet.count) unique")

        // Complete delivery: all elements must be received
        #expect(receivedSet.count == elementCount,
            "Element loss: expected \(elementCount), got \(receivedSet.count)")

        #expect(receivedSet == Set(0..<elementCount),
            "Missing elements: \(Set(0..<elementCount).subtracting(receivedSet))")
    }

    @Test("Direct delivery when receiver waiting - funnel correctness")
    func directDeliveryWhenReceiverWaiting() async throws {
        // When a receiver is waiting and send() is called, the element should be
        // delivered directly (not buffered). This tests pump(sending:) funnel.
        // Fresh channel per round to ensure isolation.
        for round in 0..<100 {
            let channel = Async.Channel.Unbounded<Int>()

            // Start receiver first
            let receiveTask = Task {
                try await channel.receive()
            }

            // Yield to let it suspend (no wall-clock sleep)
            await yieldProgress(iterations: 10)

            // Send element
            try channel.send(round)

            // Should receive the sent element
            let value = try await receiveTask.value
            #expect(value == round, "Round \(round): Expected \(round), got \(String(describing: value))")

            // Buffer should be empty (element was delivered directly)
            channel.close()
            let remaining = try await channel.receive()
            #expect(remaining == nil, "Round \(round): Buffer should be empty after direct delivery")
        }
    }
}
