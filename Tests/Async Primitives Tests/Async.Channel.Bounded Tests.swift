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

@Suite("Async.Channel.Bounded")
struct BoundedChannelTests {

    @Test("Send and receive single element")
    func sendReceiveSingleElement() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        try await channel.send(42)
        channel.close()
        let value = try await channel.receive()
        #expect(value == 42)
    }

    @Test("Send succeeds when channel has space")
    func sendSucceeds() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 10)
        try await channel.send(42)
        channel.close()
    }

    @Test("Closed channel rejects send")
    func closedChannelRejectsSend() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        channel.close()
        do {
            try await channel.send(42)
            Issue.record("Expected send to throw .closed")
        } catch .closed {
            // Expected
        } catch {
            Issue.record("Expected .closed but got \(error)")
        }
    }

    @Test("Try send returns false when full")
    func trySendReturnsFalseWhenFull() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        let first = channel.send.tryOne(1)
        let second = channel.send.tryOne(2)
        #expect(first == true)
        #expect(second == false)
    }

    @Test("Receive returns nil after close and drain")
    func receiveReturnsNilAfterCloseAndDrain() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 10)
        try await channel.send(1)
        try await channel.send(2)
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
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        let result = channel.receive.tryOne()
        #expect(result == nil)
    }

    @Test("Try receive returns element when available")
    func tryReceiveReturnsElement() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        try await channel.send(42)
        let result = channel.receive.tryOne()
        #expect(result == 42)
    }

    @Test("isClosed reflects state")
    func isClosedReflectsState() {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        #expect(channel.isClosed == false)
        channel.close()
        #expect(channel.isClosed == true)
    }

    @Test("Receive suspends until element available")
    func receiveSuspendsUntilElement() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        let started = Async.Barrier(parties: 2)

        // Start receive in background
        let receiveTask = Task {
            await started.arrive()  // Signal ready
            return try await channel.receive()
        }

        // Wait for task to be ready
        await started.arrive()

        // Send element
        try await channel.send(42)

        // Receive should complete with the element
        let result = try await receiveTask.value
        #expect(result == 42)
    }

    @Test("Receive resumes with nil on close")
    func receiveResumesOnClose() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        let started = Async.Barrier(parties: 2)

        // Start receive in background
        let receiveTask = Task {
            await started.arrive()  // Signal ready
            return try await channel.receive()
        }

        // Wait for task to be ready
        await started.arrive()

        // Close channel
        channel.close()

        // Receive should complete with nil
        let result = try await receiveTask.value
        #expect(result == nil)
    }

    @Test("Send suspends when buffer is full")
    func sendSuspendsWhenFull() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        let started = Async.Barrier(parties: 2)

        // Fill the buffer
        try await channel.send(1)

        // Start another send in background (should suspend)
        let sendTask = Task {
            await started.arrive()  // Signal ready
            try await channel.send(2)
        }

        // Wait for task to be ready
        await started.arrive()

        // Receive to make space
        let first = try await channel.receive()
        #expect(first == 1)

        // Send should complete without error
        try await sendTask.value

        // Get the second element
        let second = try await channel.receive()
        #expect(second == 2)
    }

    @Test("Close cancels pending sends")
    func closeCancelsPendingSends() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        let started = Async.Barrier(parties: 2)

        // Fill the buffer
        try await channel.send(1)

        // Start another send in background (should suspend)
        let sendTask = Task { () -> Async.Channel.Error? in
            await started.arrive()  // Signal ready
            do {
                try await channel.send(2)
                return nil
            } catch let error as Async.Channel.Error {
                return error
            } catch {
                return nil
            }
        }

        // Wait for task to be ready
        await started.arrive()

        // Close the channel
        channel.close()

        // Send should return .closed error
        let error = await sendTask.value
        #expect(error == .closed)
    }

    @Test("Backpressure maintains order")
    func backpressureMaintainsOrder() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 2)

        // Producer task
        let producer = Task {
            for i in 1...5 {
                try await channel.send(i)
            }
            channel.close()
        }

        // Consumer task
        var received: [Int] = []
        while let value = try await channel.receive() {
            received.append(value)
        }

        try await producer.value

        #expect(received == [1, 2, 3, 4, 5])
    }

    @Test("Direct delivery when receiver waiting")
    func directDeliveryWhenReceiverWaiting() async throws {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        let started = Async.Barrier(parties: 2)

        // Start receive in background
        let receiveTask = Task {
            await started.arrive()  // Signal ready
            return try await channel.receive()
        }

        // Wait for task to be ready
        await started.arrive()

        // Send should deliver directly without buffering
        try await channel.send(42)

        let result = try await receiveTask.value
        #expect(result == 42)
    }
}
