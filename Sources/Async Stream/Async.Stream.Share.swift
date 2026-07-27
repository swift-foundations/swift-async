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
    /// Namespace for share() internals.
    public enum Share {}
}

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
        // F-002: forwarding-task lifetime now lives on `Share.State`, which
        // every consumer's `Share.Cursor` retains — see
        // Async.Stream.Share.State.swift and Async.Stream.Share.Cursor.swift.
        let state = Async.Stream<Element>.Share.State(upstream: self)

        return Self {
            let cursor = Async.Stream<Element>.Share.Cursor(state: state)
            return Iterator {
                await cursor.next()
            }
        }
    }
}
