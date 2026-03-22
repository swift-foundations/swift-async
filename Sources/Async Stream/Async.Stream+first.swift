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
    /// Returns only the first element.
    ///
    /// ## Usage
    /// ```swift
    /// let first = stream.first()
    /// for await value in first { print(value) }  // prints one element
    /// ```
    ///
    /// - Returns: A stream that emits only the first element.
    public func first() -> Self {
        prefix(1)
    }

    /// Returns only the first element matching predicate.
    ///
    /// ## Usage
    /// ```swift
    /// let firstEven = numbers.first { $0 % 2 == 0 }
    /// ```
    ///
    /// - Parameter predicate: A function to test elements.
    /// - Returns: A stream that emits the first matching element.
    public func first(
        where predicate: @escaping @Sendable (Element) -> Bool
    ) -> Self {
        filter(predicate).first()
    }
}
