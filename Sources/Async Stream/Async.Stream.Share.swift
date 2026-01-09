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

// MARK: - Share

extension Async.Stream {
    /// Shares a single subscription among multiple consumers.
    ///
    /// Without sharing, each consumer creates its own subscription to the
    /// upstream source. With sharing, all consumers receive elements from
    /// a single upstream subscription.
    ///
    /// ## Usage
    /// ```swift
    /// let shared = expensiveStream.share()
    ///
    /// // Both consumers share the same upstream subscription
    /// Task { for await x in shared { } }
    /// Task { for await x in shared { } }
    /// ```
    ///
    /// - Returns: A shared stream backed by Broadcast.
    public func share() -> Self {
        let broadcast = Async.Broadcast<Element>()

        // Start forwarding
        Task { [self] in
            for await element in self {
                broadcast.send(element)
            }
            broadcast.finish()
        }

        return Self {
            let subscription = broadcast.subscribe()
            let box = Async.Stream<Element>.Iterator.Box(subscription.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }
}
