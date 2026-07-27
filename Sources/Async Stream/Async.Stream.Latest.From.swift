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

extension Async.Stream.Latest {
    /// Combines with the latest value from another stream.
    ///
    /// Each time this stream emits, combines with the most recent
    /// value from the other stream.
    ///
    /// ## Usage
    /// ```swift
    /// let combined = clicks.latest.from(position)
    /// // Emits (click, latestPosition) on each click
    /// ```
    ///
    /// - Parameter other: The stream to sample from.
    /// - Returns: A stream of combined elements.
    public func from<Other: Sendable>(
        _ other: Async.Stream<Other>
    ) -> Async.Stream<(Element, Other)> {
        Async.Stream<(Element, Other)> { [base] in
            let state = Async.Stream<Element>.Latest.State<Other>(source: base, other: other)
            return Async.Stream<(Element, Other)>.Iterator {
                await state.next()
            }
        }
    }

    /// Combines with the latest value from another stream using a transform.
    ///
    /// - Parameters:
    ///   - other: The stream to sample from.
    ///   - transform: Function to combine the values.
    /// - Returns: A stream of transformed combinations.
    public func from<Other: Sendable, Result: Sendable>(
        _ other: Async.Stream<Other>,
        _ transform: @escaping @Sendable (Element, Other) -> Result
    ) -> Async.Stream<Result> {
        self.from(other).map { transform($0.0, $0.1) }
    }
}
