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

extension Async.Stream {
    /// Filters elements using a predicate.
    ///
    /// ## Usage
    /// ```swift
    /// let positives = numbers.filter { $0 > 0 }
    /// ```
    ///
    /// - Parameter predicate: A function that returns true for elements to keep.
    /// - Returns: A stream of filtered elements.
    public func filter(
        _ predicate: @escaping @Sendable (Element) -> Bool
    ) -> Self {
        Self { [self] in
            let box = Async.Stream<Element>.Iterator.Box(self.makeAsyncIterator())
            return Iterator {
                while true {
                    guard let element = await box.next() else { return nil }
                    if predicate(element) {
                        return element
                    }
                }
            }
        }
    }

    /// Filters elements using an async predicate.
    ///
    /// - Parameter predicate: An async function that returns true for elements to keep.
    /// - Returns: A stream of filtered elements.
    public func filter(
        _ predicate: @escaping @Sendable (Element) async -> Bool
    ) -> Self {
        Self { [self] in
            let box = Async.Stream<Element>.Iterator.Box(self.makeAsyncIterator())
            return Iterator {
                while true {
                    guard let element = await box.next() else { return nil }
                    if await predicate(element) {
                        return element
                    }
                }
            }
        }
    }
}
