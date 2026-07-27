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
    /// Accumulates values and emits each intermediate result.
    ///
    /// ## Usage
    /// ```swift
    /// let runningTotal = numbers.scan(0) { sum, n in sum + n }
    /// // 1, 3, 6, 10, 15... for input 1, 2, 3, 4, 5
    /// ```
    ///
    /// - Parameters:
    ///   - initial: The initial accumulator value.
    ///   - accumulator: A function to combine accumulator and element.
    /// - Returns: A stream of accumulated values.
    public func scan<Result: Sendable>(
        _ initial: sending Result,
        _ accumulator: @escaping @Sendable (Result, Element) -> Result
    ) -> Async.Stream<Result> {
        let captured = initial
        return Async.Stream<Result> { [self] in
            let state = Async.Stream<Element>.Scan.State(stream: self, initial: captured, accumulator: accumulator)
            return Async.Stream<Result>.Iterator {
                await state.next()
            }
        }
    }
}
