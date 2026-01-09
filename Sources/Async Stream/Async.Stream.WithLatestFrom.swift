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
    /// WithLatestFrom accessor.
    public var withLatestFrom: WithLatestFrom { WithLatestFrom(base: self) }

    /// WithLatestFrom operations namespace.
    public struct WithLatestFrom: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream.WithLatestFrom {
    /// Combines with the latest value from another stream.
    ///
    /// Each time this stream emits, combines with the most recent
    /// value from the other stream.
    ///
    /// ## Usage
    /// ```swift
    /// let combined = clicks.withLatestFrom(position)
    /// // Emits (click, latestPosition) on each click
    /// ```
    ///
    /// - Parameter other: The stream to sample from.
    /// - Returns: A stream of combined elements.
    public func callAsFunction<Other: Sendable>(
        _ other: Async.Stream<Other>
    ) -> Async.Stream<(Element, Other)> {
        Async.Stream<(Element, Other)> { [base] in
            let state = Async.Stream<Element>.WithLatestFrom.State<Other>(source: base, other: other)
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
    public func callAsFunction<Other: Sendable, Result: Sendable>(
        _ other: Async.Stream<Other>,
        _ transform: @escaping @Sendable (Element, Other) -> Result
    ) -> Async.Stream<Result> {
        self(other).map { transform($0.0, $0.1) }
    }
}
