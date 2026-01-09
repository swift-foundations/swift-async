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

extension Async.Stream.Iterator {
    /// Internal helper to wrap async iterators for capture in closures.
    @usableFromInline
    final class Box<I: AsyncIteratorProtocol>: @unchecked Sendable {
        @usableFromInline
        var iterator: I

        @usableFromInline
        init(_ iterator: I) {
            self.iterator = iterator
        }
    }
}

extension Async.Stream.Iterator.Box {
    @usableFromInline
    func next() async -> I.Element? {
        try? await iterator.next()
    }
}
