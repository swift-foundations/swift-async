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
