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

extension Async.Stream.Map {
    /// Flat map operations namespace.
    ///
    /// Provides serial flatMap via `callAsFunction`
    /// and switching flatMap via `latest`.
    ///
    /// ## Usage
    /// ```swift
    /// stream.map.flat { Async.Stream.from($0.items) }     // flatMap
    /// stream.map.flat.latest { searchResults($0) }        // flatMapLatest
    /// ```
    public struct Flat: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }

    /// Flat accessor for flat map operations.
    public var flat: Flat { Flat(base: base) }
}

// MARK: - FlatMap (callAsFunction)

extension Async.Stream.Map.Flat {
    /// Transforms each element into a stream and flattens the results.
    ///
    /// Inner streams are consumed serially.
    ///
    /// - Parameter transform: A function that returns a stream for each element.
    /// - Returns: A stream that concatenates all inner streams.
    public func callAsFunction<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let state = Async.Stream<Element>.Map.Flat.State<U>(
                stream: base,
                transform: .sync(transform)
            )
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }

    /// Transforms each element into a stream using an async transform and flattens the results.
    ///
    /// - Parameter transform: An async function that returns a stream for each element.
    /// - Returns: A stream that concatenates all inner streams.
    public func callAsFunction<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let state = Async.Stream<Element>.Map.Flat.State<U>(
                stream: base,
                transform: .async(transform)
            )
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }
}
