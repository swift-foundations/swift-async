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
    /// Drop operations namespace.
    public struct Drop: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {
    /// Drop accessor for drop operations.
    public var drop: Drop { Drop(base: self) }
}

extension Async.Stream.Drop {
    /// Skips the first N elements.
    ///
    /// ## Usage
    /// ```swift
    /// let afterThree = stream.drop(3)
    /// ```
    ///
    /// - Parameter count: Number of elements to skip.
    /// - Returns: A stream that skips the first count elements.
    public func callAsFunction(_ count: Int) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Drop.Count(stream: base, count: count)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }

    /// Skips elements while predicate is true.
    ///
    /// ## Usage
    /// ```swift
    /// let afterNegatives = numbers.drop.while { $0 < 0 }
    /// ```
    ///
    /// - Parameter predicate: A function that returns true to skip.
    /// - Returns: A stream that starts after predicate returns false.
    public func `while`(
        _ predicate: @escaping @Sendable (Element) -> Bool
    ) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Drop.While(stream: base, predicate: predicate)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }
}
