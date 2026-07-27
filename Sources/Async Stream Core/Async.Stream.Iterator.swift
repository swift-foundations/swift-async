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

extension Async.Stream {
    /// The iterator for a stream.
    ///
    /// Wraps an async next function that produces elements.
    public struct Iterator: AsyncIteratorProtocol, Sendable {
        @usableFromInline
        let _next: @Sendable () async -> Element?

        /// Creates an iterator from a next function.
        ///
        /// - Parameter next: A sendable async closure that returns the next element.
        @inlinable
        public init(_ next: @escaping @Sendable () async -> Element?) {
            self._next = next
        }
    }
}

extension Async.Stream.Iterator {
    @inlinable
    public func next() async -> Element? {
        await _next()
    }
}
