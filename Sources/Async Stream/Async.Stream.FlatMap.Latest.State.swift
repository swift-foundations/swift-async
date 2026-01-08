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

extension Async.Stream.FlatMap {
    /// Namespace for flatMapLatest operations.
    public enum Latest {}
}

extension Async.Stream.FlatMap.Latest {
    /// Internal state for flatMapLatest.
    @usableFromInline
    actor State<U: Sendable> {
        @usableFromInline
        let outerBox: _Async.Stream<Element>.Iterator.Box<_Async.Stream<Element>.Iterator>

        @usableFromInline
        let transform: @Sendable (Element) -> _Async.Stream<U>

        @usableFromInline
        var innerTask: Task<Void, Never>?

        @usableFromInline
        var innerValues: [U] = []

        @usableFromInline
        var continuation: CheckedContinuation<U?, Never>?

        @usableFromInline
        var outerDone: Bool = false

        @usableFromInline
        var innerDone: Bool = true

        @usableFromInline
        init(stream: _Async.Stream<Element>, transform: @escaping @Sendable (Element) -> _Async.Stream<U>) {
            self.outerBox = _Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.transform = transform
        }
    }
}

extension Async.Stream.FlatMap.Latest.State {
    @usableFromInline
    func next() async -> U? {
        while true {
            // Return buffered inner value if available
            if !innerValues.isEmpty {
                return innerValues.removeFirst()
            }

            // If inner is done and outer is done, we're complete
            if innerDone && outerDone {
                return nil
            }

            // Try to get next outer element
            if innerDone {
                guard let outerElement = await outerBox.next() else {
                    outerDone = true
                    return nil
                }

                // Cancel any existing inner task
                innerTask?.cancel()
                innerDone = false

                // Start new inner stream
                let innerStream = transform(outerElement)
                innerTask = Task {
                    for await innerElement in innerStream {
                        await self.receiveInner(innerElement)
                    }
                    await self.markInnerDone()
                }
            }

            // Wait for inner value or completion
            return await withCheckedContinuation { cont in
                self.continuation = cont
            }
        }
    }

    @usableFromInline
    func receiveInner(_ element: U) async {
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: element)
        } else {
            innerValues.append(element)
        }
    }

    @usableFromInline
    func markInnerDone() async {
        innerDone = true
        if let cont = continuation {
            continuation = nil
            // Resume to re-check state
            cont.resume(returning: nil)
        }
    }
}

// MARK: - FlatMapLatest Method (sync)

extension Async.Stream {
    /// Transforms each element into a stream, cancelling previous inner streams.
    ///
    /// Unlike `flatMap` which concatenates all inner streams, `flatMapLatest`
    /// cancels the current inner stream when a new outer element arrives.
    ///
    /// ## Usage
    /// ```swift
    /// let results = searchText.flatMapLatest { query in
    ///     Async.Stream.from(search(query))
    /// }
    /// // New search cancels previous in-flight search
    /// ```
    ///
    /// - Parameter transform: A function that returns a stream for each element.
    /// - Returns: A stream from the latest inner stream.
    public func flatMapLatest<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [self] in
            let state = Async.Stream<Element>.FlatMap.Latest.State<U>(stream: self, transform: transform)
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }
}
