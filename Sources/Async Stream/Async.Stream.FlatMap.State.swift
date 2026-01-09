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
    /// Namespace for flatMap operations.
    public enum FlatMap {}
}

extension Async.Stream.FlatMap {
    /// Internal state for flatMap.
    @usableFromInline
    actor State<U: Sendable> {
        @usableFromInline
        let outerBox: _Async.Stream<Element>.Iterator.Box<_Async.Stream<Element>.Iterator>

        @usableFromInline
        let transform: @Sendable (Element) -> _Async.Stream<U>

        @usableFromInline
        var innerBox: _Async.Stream<Element>.Iterator.Box<_Async.Stream<U>.Iterator>?

        @usableFromInline
        init(stream: _Async.Stream<Element>, transform: @escaping @Sendable (Element) -> _Async.Stream<U>) {
            self.outerBox = _Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.transform = transform
        }
    }
}

extension Async.Stream.FlatMap.State {
    @usableFromInline
    func next() async -> U? {
        while true {
            // Try to get from current inner stream
            if let inner = innerBox, let element = await inner.next() {
                return element
            }

            // Get next outer element
            guard let outerElement = await outerBox.next() else {
                return nil
            }

            // Create new inner stream
            let innerStream = transform(outerElement)
            innerBox = _Async.Stream<Element>.Iterator.Box(innerStream.makeAsyncIterator())
        }
    }
}

// MARK: - FlatMap Method (sync)

extension Async.Stream {
    /// Transforms each element into a stream and flattens the results.
    ///
    /// ## Usage
    /// ```swift
    /// let allItems = users.flatMap { user in
    ///     Async.Stream.from(user.items)
    /// }
    /// ```
    ///
    /// - Parameter transform: A function that returns a stream for each element.
    /// - Returns: A stream that concatenates all inner streams.
    public func flatMap<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [self] in
            let state = Async.Stream<Element>.FlatMap.State<U>(stream: self, transform: transform)
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }
}
