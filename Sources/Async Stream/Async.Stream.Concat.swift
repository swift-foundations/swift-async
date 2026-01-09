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
    /// Concat operations namespace.
    public struct Concat: Sendable {}
}

extension Async.Stream {
    /// Concat accessor for concatenation operations.
    public static var concat: Concat { Concat() }
}

extension Async.Stream.Concat {
    /// Concatenates streams, emitting all elements from each in order.
    ///
    /// ## Usage
    /// ```swift
    /// let all = Async.Stream.concat(first, second)
    /// // Emits all of 'first', then all of 'second'
    /// ```
    ///
    /// - Parameters:
    ///   - a: First stream.
    ///   - b: Second stream.
    /// - Returns: A stream that emits all elements from both streams sequentially.
    public func callAsFunction(
        _ a: Async.Stream<Element>,
        _ b: Async.Stream<Element>
    ) -> Async.Stream<Element> {
        Async.Stream<Element> {
            let state = Async.Stream<Element>.Concat.State(a: a, b: b)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }

    /// Concatenates three streams.
    public func callAsFunction(
        _ a: Async.Stream<Element>,
        _ b: Async.Stream<Element>,
        _ c: Async.Stream<Element>
    ) -> Async.Stream<Element> {
        self(self(a, b), c)
    }

    /// Concatenates an array of streams.
    public func callAsFunction(
        _ streams: [Async.Stream<Element>]
    ) -> Async.Stream<Element> {
        guard !streams.isEmpty else { return .empty }
        return streams.dropFirst().reduce(streams[0]) { self($0, $1) }
    }
}
