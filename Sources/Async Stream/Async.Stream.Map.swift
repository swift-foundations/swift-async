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
internal import Ownership_Primitives

extension Async.Stream {
    /// Map operations namespace.
    ///
    /// Provides element transformation via `callAsFunction`,
    /// compact transformation via `compact`, and access to
    /// `flat` for stream-producing transforms.
    ///
    /// ## Usage
    /// ```swift
    /// stream.map { $0 * 2 }           // map
    /// stream.map.compact { Int($0) }   // compactMap
    /// stream.map.flat { inner($0) }    // flatMap
    /// stream.map.flat.latest { ... }   // flatMapLatest
    /// ```
    public struct Map: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {
    /// Map accessor for transformation operations.
    public var map: Map { Map(base: self) }
}

// MARK: - Map (callAsFunction)

extension Async.Stream.Map {
    /// Transforms each element using a function.
    ///
    /// - Parameter transform: A function to apply to each element.
    /// - Returns: A stream of transformed elements.
    public func callAsFunction<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> U
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let box = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                guard let element = await box.next() else { return nil }
                return transform(element)
            }
        }
    }

    /// Transforms each element using an async function.
    ///
    /// - Parameter transform: An async function to apply to each element.
    /// - Returns: A stream of transformed elements.
    public func callAsFunction<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> U
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let box = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                guard let element = await box.next() else { return nil }
                return await transform(element)
            }
        }
    }
}

// MARK: - Compact

extension Async.Stream.Map {
    /// Transforms and filters elements in one step.
    ///
    /// ## Usage
    /// ```swift
    /// let numbers = strings.map.compact { Int($0) }
    /// ```
    ///
    /// - Parameter transform: A function that returns nil for elements to filter out.
    /// - Returns: A stream of non-nil transformed elements.
    public func compact<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> U?
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let box = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                while true {
                    guard let element = await box.next() else { return nil }
                    if let transformed = transform(element) {
                        return transformed
                    }
                }
            }
        }
    }

    /// Transforms and filters elements using an async function.
    ///
    /// - Parameter transform: An async function that returns nil for elements to filter out.
    /// - Returns: A stream of non-nil transformed elements.
    public func compact<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> U?
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let box = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                while true {
                    guard let element = await box.next() else { return nil }
                    if let transformed = await transform(element) {
                        return transformed
                    }
                }
            }
        }
    }
}
