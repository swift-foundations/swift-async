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
internal import Standard_Library_Extensions

extension Async.Stream {
    /// Merge operations namespace.
    public struct Merge: Sendable {}
}

extension Async.Stream {
    /// Merge accessor for merge operations.
    public static var merge: Merge { Merge() }
}

extension Async.Stream.Merge {
    /// Merges two streams, emitting elements as they arrive.
    ///
    /// ## Usage
    /// ```swift
    /// let merged = Async.Stream.merge(stream1, stream2)
    /// ```
    ///
    /// - Parameters:
    ///   - a: First stream.
    ///   - b: Second stream.
    /// - Returns: A stream that emits from both sources.
    public func callAsFunction(
        _ a: Async.Stream<Element>,
        _ b: Async.Stream<Element>
    ) -> Async.Stream<Element> {
        Async.Stream<Element> {
            let state = Async.Stream<Element>.Merge.State()

            // Start both streams
            let task1 = Task {
                await state.run { state in
                    for await element in a {
                        state.send(element)
                    }
                    state.complete()
                }
            }

            let task2 = Task {
                await state.run { state in
                    for await element in b {
                        state.send(element)
                    }
                    state.complete()
                }
            }

            return Async.Stream<Element>.Iterator {
                let result = await state.receive()
                if result == nil {
                    task1.cancel()
                    task2.cancel()
                }
                return result
            }
        }
    }

    /// Merges three streams.
    public func callAsFunction(
        _ a: Async.Stream<Element>,
        _ b: Async.Stream<Element>,
        _ c: Async.Stream<Element>
    ) -> Async.Stream<Element> {
        self(self(a, b), c)
    }

    /// Merges an array of streams.
    public func callAsFunction(
        _ streams: [Async.Stream<Element>]
    ) -> Async.Stream<Element> {
        guard !streams.isEmpty else { return .empty }
        return streams.dropFirst().reduce(streams[0]) { self($0, $1) }
    }
}
