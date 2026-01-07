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

@Suite("Async.Channel.Bounded")
struct BoundedChannelTests {

    @Test("Send and receive single element")
    func sendReceiveSingleElement() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        let sent = await channel.send(42)
        #expect(sent == true)
        channel.close()
        let value = await channel.receive()
        #expect(value == 42)
    }

    @Test("Send returns true when channel has space")
    func sendReturnsTrue() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 10)
        let result = await channel.send(42)
        #expect(result == true)
        channel.close()
    }

    @Test("Closed channel rejects send")
    func closedChannelRejectsSend() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        channel.close()
        let result = await channel.send(42)
        #expect(result == false)
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
    func receiveReturnsNilAfterCloseAndDrain() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 10)
        _ = await channel.send(1)
        _ = await channel.send(2)
        channel.close()

        let first = await channel.receive()
        let second = await channel.receive()
        let third = await channel.receive()

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
    func tryReceiveReturnsElement() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)
        _ = await channel.send(42)
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
    func receiveSuspendsUntilElement() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)

        // Start receive in background
        let receiveTask = Task {
            await channel.receive()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Send element
        _ = await channel.send(42)

        // Receive should complete with the element
        let result = await receiveTask.value
        #expect(result == 42)
    }

    @Test("Receive resumes with nil on close")
    func receiveResumesOnClose() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)

        // Start receive in background
        let receiveTask = Task {
            await channel.receive()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Close channel
        channel.close()

        // Receive should complete with nil
        let result = await receiveTask.value
        #expect(result == nil)
    }

    @Test("Send suspends when buffer is full")
    func sendSuspendsWhenFull() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)

        // Fill the buffer
        _ = await channel.send(1)

        // Start another send in background (should suspend)
        let sendTask = Task {
            await channel.send(2)
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Receive to make space
        let first = await channel.receive()
        #expect(first == 1)

        // Send should complete
        let sent = await sendTask.value
        #expect(sent == true)

        // Get the second element
        let second = await channel.receive()
        #expect(second == 2)
    }

    @Test("Close cancels pending sends")
    func closeCancelsPendingSends() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)

        // Fill the buffer
        _ = await channel.send(1)

        // Start another send in background (should suspend)
        let sendTask = Task {
            await channel.send(2)
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Close the channel
        channel.close()

        // Send should return false
        let sent = await sendTask.value
        #expect(sent == false)
    }

    @Test("Backpressure maintains order")
    func backpressureMaintainsOrder() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 2)

        // Producer task
        let producer = Task {
            for i in 1...5 {
                _ = await channel.send(i)
            }
            channel.close()
        }

        // Consumer task
        var received: [Int] = []
        while let value = await channel.receive() {
            received.append(value)
        }

        await producer.value

        #expect(received == [1, 2, 3, 4, 5])
    }

    @Test("Direct delivery when receiver waiting")
    func directDeliveryWhenReceiverWaiting() async {
        let channel = Async.Channel.Bounded<Int>(capacity: 1)

        // Start receive in background
        let receiveTask = Task {
            await channel.receive()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Send should deliver directly without buffering
        let sent = await channel.send(42)
        #expect(sent == true)

        let result = await receiveTask.value
        #expect(result == 42)
    }
}
