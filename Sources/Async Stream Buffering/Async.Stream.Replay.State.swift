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

public import Async_Primitives

extension Async.Stream.Replay {
    /// Internal state for replay.
    @usableFromInline
    actor State {
        @usableFromInline
        var buffer: [Element] = []

        @usableFromInline
        let bufferSize: Int

        @usableFromInline
        var subscriptions: [Async.Stream<Element>.Replay.Subscription] = []

        @usableFromInline
        var finished: Bool = false

        @usableFromInline
        init(bufferSize: Int) {
            self.bufferSize = max(0, bufferSize)
        }
    }
}

extension Async.Stream.Replay.State {
    @usableFromInline
    func send(_ element: sending Element) {
        // Add to buffer
        buffer.append(element)
        if buffer.count > bufferSize {
            buffer.removeFirst()
        }

        // Forward to all subscriptions
        for subscription in subscriptions {
            subscription.receive(element)
        }
    }

    @usableFromInline
    func finish() {
        finished = true
        for subscription in subscriptions {
            subscription.finish()
        }
    }

    @usableFromInline
    func subscribe() -> Async.Stream<Element>.Replay.Subscription {
        let subscription = Async.Stream<Element>.Replay.Subscription(replay: buffer, finished: finished)
        if !finished {
            subscriptions.append(subscription)
        }
        return subscription
    }

    @usableFromInline
    func unsubscribe(_ subscription: Async.Stream<Element>.Replay.Subscription) {
        subscriptions.removeAll { $0 === subscription }
    }
}
