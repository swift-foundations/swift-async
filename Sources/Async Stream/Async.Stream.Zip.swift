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
public import Reference_Primitives

extension Async.Stream {
    /// Zip operations namespace.
    public struct Zip: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {
    /// Zip accessor for zip operations.
    public var zip: Zip { Zip(base: self) }
}

extension Async.Stream.Zip {
    /// Zips two streams into pairs.
    ///
    /// Emits a tuple when both streams have produced an element.
    /// Completes when either stream completes.
    ///
    /// ## Usage
    /// ```swift
    /// let pairs = stream1.zip(stream2)
    /// for await (a, b) in pairs { }
    /// ```
    ///
    /// - Parameter other: The stream to zip with.
    /// - Returns: A stream of tuples.
    public func callAsFunction<Other: Sendable>(
        _ other: Async.Stream<Other>
    ) -> Async.Stream<(Element, Other)> {
        Async.Stream<(Element, Other)> { [base] in
            let boxA = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            let boxB = Async.Stream<Element>.Iterator.Box(other.makeAsyncIterator())

            return Async.Stream<(Element, Other)>.Iterator {
                async let a = boxA.next()
                async let b = boxB.next()

                guard let elementA = await a, let elementB = await b else {
                    return nil
                }

                return (elementA, elementB)
            }
        }
    }

    /// Zips with another stream, applying a transform.
    ///
    /// - Parameters:
    ///   - other: The stream to zip with.
    ///   - transform: A function to combine elements.
    /// - Returns: A stream of transformed pairs.
    public func callAsFunction<Other: Sendable, Result: Sendable>(
        _ other: Async.Stream<Other>,
        _ transform: @escaping @Sendable (Element, Other) -> Result
    ) -> Async.Stream<Result> {
        self(other).map { transform($0.0, $0.1) }
    }
}
