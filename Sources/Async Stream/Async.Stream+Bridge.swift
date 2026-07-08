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
internal import Ownership_Primitives

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
    /// Creates a stream from an unbounded channel receiver.
    ///
    /// ## Usage
    /// ```swift
    /// var channel = Async.Channel<Int>.Unbounded()
    /// let stream = Async.Stream(from: &channel.receiver)
    /// ```
    ///
    /// - Parameter receiver: The receiver to read from (consumed).
    /// - Returns: A stream that emits channel elements.
    /// - Note: Cancellation errors from receive are treated as stream termination.
    public init(from receiver: consuming Async.Channel<Element>.Unbounded.Receiver) {
        // Use the public elements accessor to get the AsyncSequence
        let elements = receiver.elements
        self.init {
            let box = Async.Stream<Element>.Iterator.Box(elements.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }
}

// MARK: - From Channel.Bounded

extension Async.Stream {
    /// Creates a stream from a bounded channel receiver.
    ///
    /// ## Usage
    /// ```swift
    /// let (sender, receiver) = Async.Channel<Int>.Bounded.create(capacity: 10)
    /// let stream = Async.Stream(from: receiver)
    /// ```
    ///
    /// - Parameter receiver: The receiver to read from (consumed).
    /// - Returns: A stream that emits channel elements.
    public init(from receiver: consuming Async.Channel<Element>.Bounded.Receiver) {
        let elements = receiver.elements
        self.init {
            let box = Async.Stream<Element>.Iterator.Box(elements.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }
}

// MARK: - To Channel

extension Async.Stream {
    /// Forwards elements to an unbounded channel sender.
    ///
    /// ## Usage
    /// ```swift
    /// let (sender, receiver) = Async.Channel<Int>.Unbounded.create()
    /// let task = stream.forward(to: sender)
    /// ```
    ///
    /// - Parameter sender: The sender to forward to.
    /// - Returns: A task that forwards elements.
    /// - Note: Stops forwarding if the channel is closed.
    @discardableResult
    public func forward(to sender: Async.Channel<Element>.Unbounded.Sender) -> Task<Void, Never> {
        Task {
            forwarding: for await element in self {
                do throws(Async.Channel<Element>.Error) {
                    try sender.send(element)
                } catch {
                    break forwarding
                }
            }
            sender.close()
        }
    }

    /// Forwards elements to a bounded channel sender.
    ///
    /// ## Usage
    /// ```swift
    /// let (sender, receiver) = Async.Channel<Int>.Bounded.create(capacity: 10)
    /// let task = stream.forward(to: sender)
    /// ```
    ///
    /// - Parameter sender: The sender to forward to.
    /// - Returns: A task that forwards elements.
    @discardableResult
    public func forward(to sender: Async.Channel<Element>.Bounded.Sender) -> Task<Void, Never> {
        Task {
            forwarding: for await element in self {
                do throws(Async.Channel<Element>.Error) {
                    try await sender.send(element)
                } catch {
                    break forwarding
                }
            }
            sender.close()
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

extension Async.Channel.Unbounded.Receiver where Element: Sendable {
    /// Creates a stream from this receiver (consumes the receiver).
    ///
    /// Requires `Element: Sendable` because `Async.Stream` is a Sendable,
    /// type-erased async sequence. For non-Sendable elements, use
    /// `receiver.elements` directly.
    ///
    /// ## Usage
    /// ```swift
    /// var channel = Async.Channel<Int>.Unbounded()
    /// let stream = channel.receiver.stream()
    /// ```
    public consuming func stream() -> Async.Stream<Element> {
        Async.Stream(from: consume self)
    }
}

extension Async.Channel.Bounded.Receiver where Element: Sendable {
    /// Creates a stream from this receiver (consumes the receiver).
    ///
    /// Requires `Element: Sendable` because `Async.Stream` is a Sendable,
    /// type-erased async sequence. For non-Sendable elements, use
    /// `receiver.elements` directly.
    ///
    /// ## Usage
    /// ```swift
    /// let (sender, receiver) = Async.Channel<Int>.Bounded.create(capacity: 10)
    /// let stream = receiver.stream()
    /// ```
    public consuming func stream() -> Async.Stream<Element> {
        Async.Stream(from: consume self)
    }
}
