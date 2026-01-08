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
    /// Prefix operations namespace.
    public struct Prefix: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {
    /// Prefix accessor for prefix operations.
    public var prefix: Prefix { Prefix(base: self) }
}

extension Async.Stream.Prefix {
    /// Takes the first N elements.
    ///
    /// ## Usage
    /// ```swift
    /// let firstThree = stream.prefix(3)
    /// ```
    ///
    /// - Parameter count: Maximum number of elements to emit.
    /// - Returns: A stream limited to count elements.
    public func callAsFunction(_ count: Int) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Prefix.Count(stream: base, count: count)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }

    /// Takes elements while predicate is true.
    ///
    /// ## Usage
    /// ```swift
    /// let untilNegative = numbers.prefix.while { $0 >= 0 }
    /// ```
    ///
    /// - Parameter predicate: A function that returns true to continue.
    /// - Returns: A stream that completes when predicate returns false.
    public func `while`(
        _ predicate: @escaping @Sendable (Element) -> Bool
    ) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Prefix.While(stream: base, predicate: predicate)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }
}
