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

extension Async.Stream.Map.Flat {
    /// Transforms each element into a stream, cancelling previous inner streams.
    ///
    /// Unlike `flat` which concatenates all inner streams, `flat.latest`
    /// cancels the current inner stream when a new outer element arrives.
    ///
    /// ## Usage
    /// ```swift
    /// let results = searchText.map.flat.latest { query in
    ///     Async.Stream.from(search(query))
    /// }
    /// ```
    ///
    /// - Parameter transform: A function that returns a stream for each element.
    /// - Returns: A stream from the latest inner stream.
    public func latest<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let state = Async.Stream<Element>.Map.Flat.Latest.State<U>(
                stream: base,
                transform: .sync(transform)
            )
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }

    /// Transforms each element into a stream using an async transform, cancelling previous.
    ///
    /// - Parameter transform: An async function that returns a stream for each element.
    /// - Returns: A stream from the latest inner stream.
    public func latest<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let state = Async.Stream<Element>.Map.Flat.Latest.State<U>(
                stream: base,
                transform: .async(transform)
            )
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }
}
