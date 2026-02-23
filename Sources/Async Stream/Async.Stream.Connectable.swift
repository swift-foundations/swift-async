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
public import Ownership_Primitives

// MARK: - Multicast

extension Async.Stream {
    /// Multicasts using a provided Broadcast.
    ///
    /// Allows sharing a subscription with explicit control over
    /// when the subscription starts.
    ///
    /// ## Usage
    /// ```swift
    /// let broadcast = Async.Broadcast<Int>()
    /// let multicasted = stream.multicast(to: broadcast)
    ///
    /// // Set up subscribers first
    /// let sub1 = broadcast.subscribe()
    /// let sub2 = broadcast.subscribe()
    ///
    /// // Then start the upstream
    /// let task = multicasted.connect()
    /// ```
    ///
    /// - Parameter broadcast: The broadcast to use for multicasting.
    /// - Returns: A connectable stream.
    public func multicast(to broadcast: Async.Broadcast<Element>) -> Connectable {
        Connectable(upstream: self, broadcast: broadcast)
    }

    /// A stream that doesn't start until `connect()` is called.
    public struct Connectable: Sendable {
        @usableFromInline
        let upstream: Async.Stream<Element>

        @usableFromInline
        let broadcast: Async.Broadcast<Element>

        @usableFromInline
        init(upstream: Async.Stream<Element>, broadcast: Async.Broadcast<Element>) {
            self.upstream = upstream
            self.broadcast = broadcast
        }
    }
}

extension Async.Stream.Connectable {
    /// Starts the upstream subscription.
    ///
    /// - Returns: A task that can be cancelled to stop the upstream.
    @discardableResult
    public func connect() -> Task<Void, Never> {
        Task {
            for await element in upstream {
                broadcast.send(element)
            }
            broadcast.finish()
        }
    }

    /// Creates a stream from this connectable.
    ///
    /// - Returns: A stream that receives elements once connected.
    public func asStream() -> Async.Stream<Element> {
        Async.Stream<Element> {
            let subscription = broadcast.subscribe()
            let box = Async.Stream<Element>.Iterator.Box(subscription.makeAsyncIterator())
            return Async.Stream<Element>.Iterator {
                await box.next()
            }
        }
    }
}
