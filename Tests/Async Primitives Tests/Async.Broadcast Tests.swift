// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-runtime open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-runtime project authors
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
    func singleSubscriberReceivesAll() async {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        broadcast.send(1)
        broadcast.send(2)
        broadcast.send(3)
        broadcast.finish()

        var received: [Int] = []
        for await value in subscription {
            received.append(value)
        }

        #expect(received == [1, 2, 3])
    }

    @Test("Multiple subscribers each receive all elements")
    func multipleSubscribersReceiveAll() async {
        let broadcast = Async.Broadcast<Int>()
        let sub1 = broadcast.subscribe()
        let sub2 = broadcast.subscribe()

        broadcast.send(1)
        broadcast.send(2)
        broadcast.finish()

        let task1 = Task {
            var received: [Int] = []
            for await value in sub1 {
                received.append(value)
            }
            return received
        }

        let task2 = Task {
            var received: [Int] = []
            for await value in sub2 {
                received.append(value)
            }
            return received
        }

        let result1 = await task1.value
        let result2 = await task2.value

        #expect(result1 == [1, 2])
        #expect(result2 == [1, 2])
    }

    @Test("Late subscriber only sees new elements")
    func lateSubscriberOnlySeesNew() async {
        let broadcast = Async.Broadcast<Int>()

        broadcast.send(1)

        let subscription = broadcast.subscribe()

        broadcast.send(2)
        broadcast.send(3)
        broadcast.finish()

        var received: [Int] = []
        for await value in subscription {
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
    func subscriberSuspendsUntilElement() async {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        // Start receive in background
        let receiveTask = Task { () -> Int? in
            var iterator = subscription.makeAsyncIterator()
            return await iterator.next()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Send element
        broadcast.send(42)

        // Receive should complete with the element
        let result = await receiveTask.value
        #expect(result == 42)
    }

    @Test("Subscriber resumes with nil on finish")
    func subscriberResumesOnFinish() async {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        // Start receive in background
        let receiveTask = Task { () -> Int? in
            var iterator = subscription.makeAsyncIterator()
            return await iterator.next()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Finish broadcast
        broadcast.finish()

        // Receive should complete with nil
        let result = await receiveTask.value
        #expect(result == nil)
    }

    @Test("Cancel subscription stops iteration")
    func cancelSubscriptionStopsIteration() async {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        // Start receive in background
        let receiveTask = Task { () -> Int? in
            var iterator = subscription.makeAsyncIterator()
            return await iterator.next()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Cancel subscription
        subscription.cancel()

        // Receive should complete with nil
        let result = await receiveTask.value
        #expect(result == nil)
    }

    @Test("Elements delivered in order")
    func elementsDeliveredInOrder() async {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        for i in 1...100 {
            broadcast.send(i)
        }
        broadcast.finish()

        var received: [Int] = []
        for await value in subscription {
            received.append(value)
        }

        #expect(received == Array(1...100))
    }

    @Test("Send after finish is ignored")
    func sendAfterFinishIgnored() async {
        let broadcast = Async.Broadcast<Int>()
        let subscription = broadcast.subscribe()

        broadcast.send(1)
        broadcast.finish()
        broadcast.send(2)  // Should be ignored

        var received: [Int] = []
        for await value in subscription {
            received.append(value)
        }

        #expect(received == [1])
    }
}
