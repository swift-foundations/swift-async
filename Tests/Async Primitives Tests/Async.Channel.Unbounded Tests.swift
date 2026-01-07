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

@Suite("Async.Channel.Unbounded")
struct UnboundedChannelTests {

    @Test("Send and receive single element")
    func sendReceiveSingleElement() async {
        let channel = Async.Channel.Unbounded<Int>()
        channel.send(42)
        channel.close()
        let value = await channel.receive()
        #expect(value == 42)
    }

    @Test("Send returns true when channel is open")
    func sendReturnsTrue() {
        let channel = Async.Channel.Unbounded<Int>()
        let result = channel.send(42)
        #expect(result == true)
        channel.close()
    }

    @Test("Closed channel rejects send")
    func closedChannelRejectsSend() {
        let channel = Async.Channel.Unbounded<Int>()
        channel.close()
        let result = channel.send(42)
        #expect(result == false)
    }

    @Test("Receive returns nil after close and drain")
    func receiveReturnsNilAfterCloseAndDrain() async {
        let channel = Async.Channel.Unbounded<Int>()
        channel.send(1)
        channel.send(2)
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
        let channel = Async.Channel.Unbounded<Int>()
        let result = channel.receive.tryOne()
        #expect(result == nil)
    }

    @Test("Try receive returns element when available")
    func tryReceiveReturnsElement() {
        let channel = Async.Channel.Unbounded<Int>()
        channel.send(42)
        let result = channel.receive.tryOne()
        #expect(result == 42)
    }

    @Test("Send batch elements")
    func sendBatch() async {
        let channel = Async.Channel.Unbounded<Int>()
        let result = channel.send(contentsOf: [1, 2, 3])
        #expect(result == true)
        channel.close()

        var received: [Int] = []
        while let value = await channel.receive() {
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
    func receiveSuspendsUntilElement() async {
        let channel = Async.Channel.Unbounded<Int>()

        // Start receive in background
        let receiveTask = Task {
            await channel.receive()
        }

        // Give task time to start waiting
        try? await Task.sleep(for: .milliseconds(10))

        // Send element
        channel.send(42)

        // Receive should complete with the element
        let result = await receiveTask.value
        #expect(result == 42)
    }

    @Test("Receive resumes with nil on close")
    func receiveResumesOnClose() async {
        let channel = Async.Channel.Unbounded<Int>()

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

    @Test("Multiple producers can send concurrently")
    func multipleProducers() async {
        let channel = Async.Channel.Unbounded<Int>()
        let count = 100

        // Launch multiple producer tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    channel.send(i)
                }
            }
        }

        channel.close()

        // Collect all received values
        var received: Set<Int> = []
        while let value = await channel.receive() {
            received.insert(value)
        }

        // Should have received all values
        #expect(received.count == count)
        for i in 0..<count {
            #expect(received.contains(i))
        }
    }
}
