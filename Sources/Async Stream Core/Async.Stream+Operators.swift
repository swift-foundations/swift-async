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

// MARK: - Stateless Transform Operations

extension Async.Stream {
    /// Transforms each element using a function.
    ///
    /// ## Usage
    /// ```swift
    /// let doubled = numbers.map { $0 * 2 }
    /// ```
    ///
    /// - Parameter transform: A function to apply to each element.
    /// - Returns: A stream of transformed elements.
    public func map<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> U
    ) -> Async.Stream<U> {
        Async.Stream<U> { [self] in
            let box = Async.Stream<Element>.Iterator.Box(self.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                guard let element = await box.next() else { return nil }
                return transform(element)
            }
        }
    }

    /// Transforms each element using an async function.
    ///
    /// ## Usage
    /// ```swift
    /// let fetched = urls.map { await fetch($0) }
    /// ```
    ///
    /// - Parameter transform: An async function to apply to each element.
    /// - Returns: A stream of transformed elements.
    public func map<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> U
    ) -> Async.Stream<U> {
        Async.Stream<U> { [self] in
            let box = Async.Stream<Element>.Iterator.Box(self.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                guard let element = await box.next() else { return nil }
                return await transform(element)
            }
        }
    }

    /// Filters elements using a predicate.
    ///
    /// ## Usage
    /// ```swift
    /// let positives = numbers.filter { $0 > 0 }
    /// ```
    ///
    /// - Parameter predicate: A function that returns true for elements to keep.
    /// - Returns: A stream of filtered elements.
    public func filter(
        _ predicate: @escaping @Sendable (Element) -> Bool
    ) -> Self {
        Self { [self] in
            let box = Async.Stream<Element>.Iterator.Box(self.makeAsyncIterator())
            return Iterator {
                while true {
                    guard let element = await box.next() else { return nil }
                    if predicate(element) {
                        return element
                    }
                }
            }
        }
    }

    /// Filters elements using an async predicate.
    ///
    /// - Parameter predicate: An async function that returns true for elements to keep.
    /// - Returns: A stream of filtered elements.
    public func filter(
        _ predicate: @escaping @Sendable (Element) async -> Bool
    ) -> Self {
        Self { [self] in
            let box = Async.Stream<Element>.Iterator.Box(self.makeAsyncIterator())
            return Iterator {
                while true {
                    guard let element = await box.next() else { return nil }
                    if await predicate(element) {
                        return element
                    }
                }
            }
        }
    }

    /// Transforms and filters elements in one step.
    ///
    /// ## Usage
    /// ```swift
    /// let numbers = strings.compactMap { Int($0) }
    /// ```
    ///
    /// - Parameter transform: A function that returns nil for elements to filter out.
    /// - Returns: A stream of non-nil transformed elements.
    public func compactMap<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> U?
    ) -> Async.Stream<U> {
        Async.Stream<U> { [self] in
            let box = Async.Stream<Element>.Iterator.Box(self.makeAsyncIterator())
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
    public func compactMap<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> U?
    ) -> Async.Stream<U> {
        Async.Stream<U> { [self] in
            let box = Async.Stream<Element>.Iterator.Box(self.makeAsyncIterator())
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

    /// Reduces all elements to a single value.
    ///
    /// ## Usage
    /// ```swift
    /// let sum = await numbers.reduce(0) { $0 + $1 }
    /// ```
    ///
    /// - Parameters:
    ///   - initial: The initial accumulator value.
    ///   - accumulator: A function to combine accumulator and element.
    /// - Returns: The final accumulated value.
    public func reduce<Result: Sendable>(
        _ initial: Result,
        _ accumulator: @escaping @Sendable (Result, Element) -> Result
    ) async -> Result {
        var result = initial
        for await element in self {
            result = accumulator(result, element)
        }
        return result
    }
}
