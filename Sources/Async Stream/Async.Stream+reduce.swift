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
    /// Reduces all elements to a single value.
    ///
    /// ## Usage
    /// ```swift
    /// let sum = await numbers.reduce(0) { $0 + $1 }
    /// ```
    ///
    /// - Parameters:
    ///   - initial: The initial accumulator value.
    ///   - accumulator: A function to combine accumulator and element.
    /// - Returns: The final accumulated value.
    public func reduce<Result: Sendable>(
        _ initial: Result,
        _ accumulator: @escaping @Sendable (Result, Element) -> Result
    ) async -> Result {
        var result = initial
        for await element in self {
            result = accumulator(result, element)
        }
        return result
    }
}
