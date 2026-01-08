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

@Suite("Async.Broadcast")
struct BroadcastTests {

    @Test("Single subscriber receives all elements")
    func singleSubscriberReceivesAll() async throws {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        broadcast.send(1)
        broadcast.send(2)
        broadcast.send(3)
        broadcast.finish()

        var received: [Int] = []
        for try await value in subscription {
            received.append(value)
        }

        #expect(received == [1, 2, 3])
    }

    @Test("Multiple subscribers each receive all elements")
    func multipleSubscribersReceiveAll() async throws {
        let broadcast = Async.Broadcast<Int>()
        let sub1 = broadcast.subscribe()
        let sub2 = broadcast.subscribe()

        broadcast.send(1)
        broadcast.send(2)
        broadcast.finish()

        let task1 = Task {
            var received: [Int] = []
            for try await value in sub1 {
                received.append(value)
            }
            return received
        }

        let task2 = Task {
            var received: [Int] = []
            for try await value in sub2 {
                received.append(value)
            }
            return received
        }

        let result1 = try await task1.value
        let result2 = try await task2.value

        #expect(result1 == [1, 2])
        #expect(result2 == [1, 2])
    }

    @Test("Late subscriber only sees new elements")
    func lateSubscriberOnlySeesNew() async throws {
        let broadcast = Async.Broadcast<Int>()

        broadcast.send(1)

        let subscription = broadcast.subscribe()

        broadcast.send(2)
        broadcast.send(3)
        broadcast.finish()

        var received: [Int] = []
        for try await value in subscription {
            received.append(value)
        }

        #expect(received == [2, 3])
    }

    @Test("isFinished reflects state")
    func isFinishedReflectsState() {
        let broadcast = Async.Broadcast<Int>()
        #expect(broadcast.isFinished == false)
        broadcast.finish()
        #expect(broadcast.isFinished == true)
    }

    @Test("Subscriber suspends until element available")
    func subscriberSuspendsUntilElement() async throws {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()
        let started = Async.Barrier(parties: 2)

        // Start receive in background
        let receiveTask = Task { () -> Int? in
            await started.arrive()  // Signal ready
            var iterator = subscription.makeAsyncIterator()
            return try await iterator.next()
        }

        // Wait for task to be ready
        await started.arrive()

        // Send element
        broadcast.send(42)

        // Receive should complete with the element
        let result = try await receiveTask.value
        #expect(result == 42)
    }

    @Test("Subscriber resumes with nil on finish")
    func subscriberResumesOnFinish() async throws {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()
        let started = Async.Barrier(parties: 2)

        // Start receive in background
        let receiveTask = Task { () -> Int? in
            await started.arrive()  // Signal ready
            var iterator = subscription.makeAsyncIterator()
            return try await iterator.next()
        }

        // Wait for task to be ready
        await started.arrive()

        // Finish broadcast
        broadcast.finish()

        // Receive should complete with nil
        let result = try await receiveTask.value
        #expect(result == nil)
    }

    @Test("Cancel subscription stops iteration")
    func cancelSubscriptionStopsIteration() async throws {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()
        let started = Async.Barrier(parties: 2)

        // Start receive in background
        let receiveTask = Task { () -> Int? in
            await started.arrive()  // Signal ready
            var iterator = subscription.makeAsyncIterator()
            return try await iterator.next()
        }

        // Wait for task to be ready
        await started.arrive()

        // Cancel subscription
        subscription.cancel()

        // Receive should complete with nil
        let result = try await receiveTask.value
        #expect(result == nil)
    }

    @Test("Elements delivered in order")
    func elementsDeliveredInOrder() async throws {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        for i in 1...100 {
            broadcast.send(i)
        }
        broadcast.finish()

        var received: [Int] = []
        for try await value in subscription {
            received.append(value)
        }

        #expect(received == Array(1...100))
    }

    @Test("Send after finish is ignored")
    func sendAfterFinishIgnored() async throws {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        broadcast.send(1)
        broadcast.finish()
        broadcast.send(2)  // Should be ignored

        var received: [Int] = []
        for try await value in subscription {
            received.append(value)
        }

        #expect(received == [1])
    }

    @Test("Task cancellation throws cancelled error")
    func taskCancellationThrowsCancelled() async {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()
        let started = Async.Barrier(parties: 2)

        let receiveTask = Task {
            await started.arrive()  // Signal ready
            var iterator = subscription.makeAsyncIterator()
            return try await iterator.next()
        }

        // Wait for task to be ready
        await started.arrive()

        // Cancel the task
        receiveTask.cancel()

        // Should throw cancelled error
        do {
            _ = try await receiveTask.value
            Issue.record("Expected cancellation error")
        } catch let error as Async.Broadcast<Int>.Error {
            #expect(error == .cancelled)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Stress Tests

@Suite("Async.Broadcast.Stress")
struct BroadcastStressTests {

    /// Yield multiple times to allow concurrent tasks to make progress.
    private func yieldProgress(iterations: Int = 50) async {
        for _ in 0..<iterations {
            await Task.yield()
        }
    }

    @Test("All subscribers receive all elements - no loss")
    func allSubscribersReceiveAllElements() async throws {
        // Multiple subscribers, all should receive every element.
        // This tests the core broadcast invariant.
        for round in 0..<20 {
            let elementCount = 50
            // Explicit buffer capacity to ensure no trimming affects this test
            let broadcast = Async.Broadcast<Int>(bufferCapacity: elementCount)
            let subscriberCount = 5

            // Create subscriptions before sending
            let subscriptions = (0..<subscriberCount).map { _ in
                broadcast.subscribe()
            }

            // Start consumer tasks
            let consumerTasks = subscriptions.map { subscription in
                Task {
                    var received: [Int] = []
                    for try await value in subscription {
                        received.append(value)
                    }
                    return received
                }
            }

            // Yield to let consumers start
            await yieldProgress(iterations: 20)

            // Send all elements
            for i in 0..<elementCount {
                broadcast.send(i)
            }
            broadcast.finish()

            // Collect results from all subscribers
            for (index, task) in consumerTasks.enumerated() {
                let received = try await task.value

                // Each subscriber must receive all elements in exact order
                #expect(received.count == elementCount,
                    "Round \(round), subscriber \(index): count \(received.count) != \(elementCount)")
                #expect(received == Array(0..<elementCount),
                    "Round \(round), subscriber \(index): elements mismatch")
            }
        }
    }

    @Test("Cancellation racing with send - token matching correctness")
    func cancellationRacingWithSend() async throws {
        // Force cancelled subscribers to be in "waiting state" when cancelled.
        // Non-cancelled subscribers must still receive all elements.
        for round in 0..<30 {
            let elementCount = 20
            let broadcast = Async.Broadcast<Int>(bufferCapacity: elementCount)
            let subscriberCount = 10

            let subscriptions = (0..<subscriberCount).map { _ in
                broadcast.subscribe()
            }

            // Start consumer tasks
            let consumerTasks = subscriptions.enumerated().map { (index, subscription) in
                Task {
                    var received: [Int] = []
                    var iterator = subscription.makeAsyncIterator()
                    while true {
                        do {
                            if let value = try await iterator.next() {
                                received.append(value)
                            } else {
                                break // Finished
                            }
                        } catch let error as Async.Broadcast<Int>.Error {
                            #expect(error == .cancelled,
                                "Round \(round), subscriber \(index): Expected .cancelled, got \(error)")
                            return (index, received, true) // cancelled
                        } catch {
                            #expect(Bool(false), "Round \(round), subscriber \(index): Unexpected error: \(error)")
                            break
                        }
                    }
                    return (index, received, false) // not cancelled
                }
            }

            // Step 1: Send first element so everyone consumes one
            broadcast.send(0)
            await yieldProgress(iterations: 30)

            // Step 2: Now subscribers are waiting in next() for element 1
            // Cancel even-indexed subscribers while they are suspended
            for i in stride(from: 0, to: subscriberCount, by: 2) {
                consumerTasks[i].cancel()
            }

            // Step 3: Send remaining elements
            for i in 1..<elementCount {
                broadcast.send(i)
                await Task.yield()
            }
            broadcast.finish()

            // Collect results
            var cancelledCount = 0
            for task in consumerTasks {
                let (index, received, wasCancelled) = await task.value

                if wasCancelled {
                    cancelledCount += 1
                    // Cancelled subscribers should have received element 0 before cancellation
                    #expect(received.first == 0 || received.isEmpty,
                        "Round \(round), cancelled subscriber \(index): Unexpected first element")
                } else {
                    // Non-cancelled subscribers must have all elements in exact order
                    #expect(received == Array(0..<elementCount),
                        "Round \(round), subscriber \(index): Expected all elements")
                }
            }

            // At least some cancellations should have occurred
            #expect(cancelledCount > 0, "Round \(round): No cancellations observed")
        }
    }

    @Test("Finish racing with pending subscribers - all resume with nil")
    func finishRacingWithPendingSubscribers() async throws {
        // Subscribers created after sends, then finish() called.
        // All must resume with empty results (no hang).
        for round in 0..<30 {
            let broadcast = Async.Broadcast<Int>()
            let subscriberCount = 15
            let preBufferedCount = 5

            // Pre-send some elements (subscribers created after won't see these)
            for i in 0..<preBufferedCount {
                broadcast.send(i)
            }

            // Create subscriptions (cursor starts after pre-sent elements)
            let subscriptions = (0..<subscriberCount).map { _ in
                broadcast.subscribe()
            }

            // Start consumers
            let consumerTasks = subscriptions.map { subscription in
                Task { () -> [Int] in
                    var received: [Int] = []
                    for try await value in subscription {
                        received.append(value)
                    }
                    return received
                }
            }

            // Yield to let them start waiting
            await yieldProgress()

            // Finish immediately (no more elements after subscription)
            broadcast.finish()

            // All must complete with empty results (no hang, no error)
            for (index, task) in consumerTasks.enumerated() {
                let received = try await task.value
                // Subscriptions created after send() see nothing
                #expect(received.isEmpty,
                    "Round \(round), subscriber \(index): Expected empty, got \(received.count) elements")
            }
        }
    }

    @Test("Many subscribers with interleaved send and cancel")
    func manySubscribersInterleavedSendCancel() async throws {
        // Broad interleaving stress test for send, subscribe, and cancel.
        // Tests snapshot iteration under load. Token matching correctness is
        // tested deterministically in cancellationRacingWithSend.
        let elementCount = 100
        let broadcast = Async.Broadcast<Int>(bufferCapacity: elementCount)

        // Collector for results
        let results = Async.Channel.Unbounded<(id: Int, elements: [Int], cancelled: Bool)>()

        // Build subscriber tasks synchronously (outside group) to avoid shared mutable state
        // Store (id, task) tuples to cancel by logical id, not array index
        var subscriberTasks: [(id: Int, task: Task<Void, Never>)] = []

        // Create all subscriber tasks first
        for wave in 0..<5 {
            for subId in 0..<4 {
                let id = wave * 4 + subId
                let task = Task {
                    let subscription = broadcast.subscribe()
                    var received: [Int] = []

                    // Direct iteration - no nested Task
                    var iterator = subscription.makeAsyncIterator()
                    while true {
                        do {
                            if let value = try await iterator.next() {
                                received.append(value)
                                await Task.yield() // Allow interleaving
                            } else {
                                break // Finished
                            }
                        } catch let error as Async.Broadcast<Int>.Error {
                            #expect(error == .cancelled,
                                "Subscriber \(id): Expected .cancelled, got \(error)")
                            // Send results collected so far (not empty!)
                            do { try results.send((id: id, elements: received, cancelled: true)) }
                            catch { #expect(Bool(false), "results channel unexpectedly closed: \(error)") }
                            return
                        } catch {
                            #expect(Bool(false), "Subscriber \(id): Unexpected error: \(error)")
                            break
                        }
                    }
                    // Normal completion
                    do { try results.send((id: id, elements: received, cancelled: false)) }
                    catch { #expect(Bool(false), "results channel unexpectedly closed: \(error)") }
                }
                subscriberTasks.append((id: id, task: task))
            }
        }

        // IDs to cancel (deterministic: every 3rd subscriber)
        let idsToCancel = Set(stride(from: 0, to: 20, by: 3))

        // Start producer and cancellation in a task group
        await withTaskGroup(of: Void.self) { group in
            // Producer: send elements with yields
            group.addTask {
                for i in 0..<elementCount {
                    broadcast.send(i)
                    await Task.yield()
                }
                broadcast.finish()
            }

            // Cancellation task: cancel designated subscribers after some progress
            group.addTask { [subscriberTasks] in
                // Wait for some elements to be sent/received
                for _ in 0..<30 {
                    await Task.yield()
                }
                // Cancel by logical subscriber id
                for entry in subscriberTasks where idsToCancel.contains(entry.id) {
                    entry.task.cancel()
                }
            }

            // Wait for all subscriber tasks
            group.addTask { [subscriberTasks] in
                for entry in subscriberTasks {
                    await entry.task.value
                }
            }
        }

        // SAFETY: results.close() is safe here because all subscriber tasks
        // have completed (awaited in group) and each sends its result on exit.
        results.close()

        // Analyze results
        var totalSubscribers = 0
        var cancelledSubscribers = 0
        var cancelledWithElements = 0

        while let result = try await results.receive() {
            totalSubscribers += 1

            // Check ordering and duplicates for ALL subscribers (including cancelled)
            for i in 1..<result.elements.count {
                #expect(result.elements[i] > result.elements[i-1],
                    "Subscriber \(result.id): Elements out of order at index \(i)")
            }
            #expect(Set(result.elements).count == result.elements.count,
                "Subscriber \(result.id): Duplicates detected")
            // All elements in valid range
            for value in result.elements {
                #expect((0..<elementCount).contains(value),
                    "Subscriber \(result.id): Out-of-range value \(value)")
            }

            if result.cancelled {
                cancelledSubscribers += 1
                if !result.elements.isEmpty {
                    cancelledWithElements += 1
                }
            }
        }

        #expect(totalSubscribers == 20, "Expected 20 subscribers, got \(totalSubscribers)")
        #expect(cancelledSubscribers > 0, "Expected some cancellations")
        // Ensure interleaving actually happened (not just "cancel before first next")
        #expect(cancelledWithElements > 0,
            "Expected at least one cancelled subscriber to have received elements")
    }

    @Test("Buffer trimming with slow subscriber")
    func bufferTrimmingWithSlowSubscriber() async throws {
        // One slow subscriber, one fast subscriber.
        // Fast subscriber should not be blocked and gets all elements.
        // Slow subscriber may miss elements if it falls too far behind.
        let bufferCapacity = 10
        let broadcast = Async.Broadcast<Int>(bufferCapacity: bufferCapacity)
        let elementCount = 100

        let fastSub = broadcast.subscribe()
        let slowSub = broadcast.subscribe()

        // Fast consumer - no artificial delays
        let fastTask = Task {
            var received: [Int] = []
            for try await value in fastSub {
                received.append(value)
            }
            return received
        }

        // Slow consumer - delays between reads
        let slowTask = Task {
            var received: [Int] = []
            var iterator = slowSub.makeAsyncIterator()
            while let value = try await iterator.next() {
                received.append(value)
                // Slow down by yielding many times
                for _ in 0..<10 {
                    await Task.yield()
                }
            }
            return received
        }

        // Producer
        Task {
            for i in 0..<elementCount {
                broadcast.send(i)
                await Task.yield()
            }
            broadcast.finish()
        }

        let fastReceived = try await fastTask.value
        let slowReceived = try await slowTask.value

        // Fast subscriber should get all elements in exact order
        #expect(fastReceived == Array(0..<elementCount),
            "Fast subscriber should receive all elements in order")

        // Slow subscriber: strictly increasing (no out-of-order)
        for i in 1..<slowReceived.count {
            #expect(slowReceived[i] > slowReceived[i-1],
                "Slow subscriber elements out of order at index \(i)")
        }

        // No duplicates
        #expect(Set(slowReceived).count == slowReceived.count,
            "Slow subscriber has duplicates")

        // All received elements must be in valid range
        for value in slowReceived {
            #expect((0..<elementCount).contains(value),
                "Slow subscriber received out-of-range value: \(value)")
        }
    }

    @Test("Sequential next usage is correct")
    func sequentialNextUsageIsCorrect() async throws {
        // Demonstrates correct sequential iteration pattern.
        // (Note: Concurrent next() on same subscription is a precondition violation)
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        // Send elements
        for i in 0..<10 {
            broadcast.send(i)
        }
        broadcast.finish()

        // Sequential iteration (correct usage)
        var received: [Int] = []
        for try await value in subscription {
            received.append(value)
        }

        #expect(received == Array(0..<10))
    }
}
