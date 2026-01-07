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

public import Async_Primitives

// MARK: - From Broadcast

extension Async.Stream {
    /// Creates a stream from a Broadcast subscription.
    ///
    /// ## Usage
    /// ```swift
    /// let broadcast = Async.Broadcast<Message>()
    /// let stream = Async.Stream(from: broadcast)
    /// ```
    ///
    /// - Parameter broadcast: The broadcast to subscribe to.
    /// - Returns: A stream that emits broadcast elements.
    public init(from broadcast: Async.Broadcast<Element>) {
        self.init {
            let subscription = broadcast.subscribe()
            let box = Async.Stream<Element>.Iterator.Box(subscription.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }

    /// Creates a stream from an existing Broadcast subscription.
    ///
    /// - Parameter subscription: The subscription to wrap.
    /// - Returns: A stream that emits subscription elements.
    public init(from subscription: Async.Broadcast<Element>.Subscription) {
        self.init {
            let box = Async.Stream<Element>.Iterator.Box(subscription.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }
}

// MARK: - From Channel.Unbounded

extension Async.Stream {
    /// Creates a stream from an unbounded channel.
    ///
    /// ## Usage
    /// ```swift
    /// let channel = Async.Channel.Unbounded<Int>()
    /// let stream = Async.Stream(from: channel)
    /// ```
    ///
    /// - Parameter channel: The channel to receive from.
    /// - Returns: A stream that emits channel elements.
    public init(from channel: Async.Channel.Unbounded<Element>) {
        self.init {
            Iterator {
                await channel.receive()
            }
        }
    }
}

// MARK: - From Channel.Bounded

extension Async.Stream {
    /// Creates a stream from a bounded channel.
    ///
    /// ## Usage
    /// ```swift
    /// let channel = Async.Channel.Bounded<Int>(capacity: 10)
    /// let stream = Async.Stream(from: channel)
    /// ```
    ///
    /// - Parameter channel: The channel to receive from.
    /// - Returns: A stream that emits channel elements.
    public init(from channel: Async.Channel.Bounded<Element>) {
        self.init {
            Iterator {
                await channel.receive()
            }
        }
    }
}

// MARK: - To Channel

extension Async.Stream {
    /// Forwards elements to an unbounded channel.
    ///
    /// ## Usage
    /// ```swift
    /// let channel = Async.Channel.Unbounded<Int>()
    /// let task = stream.forward(to: channel)
    /// ```
    ///
    /// - Parameter channel: The channel to send to.
    /// - Returns: A task that forwards elements.
    @discardableResult
    public func forward(to channel: Async.Channel.Unbounded<Element>) -> Task<Void, Never> {
        Task {
            for await element in self {
                _ = channel.send(element)
            }
            channel.close()
        }
    }

    /// Forwards elements to a bounded channel.
    ///
    /// ## Usage
    /// ```swift
    /// let channel = Async.Channel.Bounded<Int>(capacity: 10)
    /// let task = stream.forward(to: channel)
    /// ```
    ///
    /// - Parameter channel: The channel to send to.
    /// - Returns: A task that forwards elements.
    @discardableResult
    public func forward(to channel: Async.Channel.Bounded<Element>) -> Task<Void, Never> {
        Task {
            for await element in self {
                _ = await channel.send(element)
            }
            channel.close()
        }
    }

    /// Forwards elements to a broadcast.
    ///
    /// ## Usage
    /// ```swift
    /// let broadcast = Async.Broadcast<Int>()
    /// let task = stream.forward(to: broadcast)
    /// ```
    ///
    /// - Parameter broadcast: The broadcast to send to.
    /// - Returns: A task that forwards elements.
    @discardableResult
    public func forward(to broadcast: Async.Broadcast<Element>) -> Task<Void, Never> {
        Task {
            for await element in self {
                broadcast.send(element)
            }
            broadcast.finish()
        }
    }
}

// MARK: - Convenience Extensions on Runtime Primitives

extension Async.Broadcast {
    /// Creates a stream from this broadcast.
    ///
    /// Each call creates a new subscription.
    ///
    /// ## Usage
    /// ```swift
    /// let stream = broadcast.stream
    /// ```
    public var stream: Async.Stream<Element> {
        Async.Stream(from: self)
    }
}

extension Async.Channel.Unbounded {
    /// Creates a stream from this channel.
    ///
    /// ## Usage
    /// ```swift
    /// let stream = channel.stream
    /// ```
    public var stream: Async.Stream<Element> {
        Async.Stream(from: self)
    }
}

extension Async.Channel.Bounded {
    /// Creates a stream from this channel.
    ///
    /// ## Usage
    /// ```swift
    /// let stream = channel.stream
    /// ```
    public var stream: Async.Stream<Element> {
        Async.Stream(from: self)
    }
}
