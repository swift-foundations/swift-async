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
    /// Namespace for distinct operations.
    public enum Distinct {}
}

extension Async.Stream.Distinct {
    /// Internal state for distinctUntilChanged.
    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let areEqual: @Sendable (Element, Element) -> Bool

        @usableFromInline
        var previous: Element?

        @usableFromInline
        init(stream: Async.Stream<Element>, areEqual: @escaping @Sendable (Element, Element) -> Bool) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.areEqual = areEqual
        }
    }
}

extension Async.Stream.Distinct.State {
    @usableFromInline
    func next() async -> Element? {
        while true {
            guard let element = await box.next() else { return nil }

            if let prev = previous, areEqual(prev, element) {
                // Skip duplicate
                continue
            }

            previous = element
            return element
        }
    }
}

// MARK: - DistinctUntilChanged Methods

extension Async.Stream where Element: Equatable {
    /// Suppresses consecutive duplicate elements.
    ///
    /// ## Usage
    /// ```swift
    /// let distinct = [1, 1, 2, 2, 2, 3, 1].asStream().distinctUntilChanged()
    /// // Emits: 1, 2, 3, 1
    /// ```
    ///
    /// - Returns: A stream without consecutive duplicates.
    public func distinctUntilChanged() -> Self {
        distinctUntilChanged(==)
    }
}

extension Async.Stream {
    /// Suppresses consecutive elements that compare equal.
    ///
    /// ## Usage
    /// ```swift
    /// let distinct = users.distinctUntilChanged { $0.id == $1.id }
    /// ```
    ///
    /// - Parameter areEqual: A function to compare consecutive elements.
    /// - Returns: A stream without consecutive duplicates.
    public func distinctUntilChanged(
        _ areEqual: @escaping @Sendable (Element, Element) -> Bool
    ) -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Distinct.State(stream: self, areEqual: areEqual)
            return Iterator {
                await state.next()
            }
        }
    }

    /// Suppresses consecutive elements with equal key values.
    ///
    /// ## Usage
    /// ```swift
    /// let distinct = users.distinctUntilChanged { $0.id }
    /// ```
    ///
    /// - Parameter key: A function to extract the key to compare.
    /// - Returns: A stream without consecutive duplicates by key.
    public func distinctUntilChanged<Key: Equatable & Sendable>(
        by key: @escaping @Sendable (Element) -> Key
    ) -> Self {
        distinctUntilChanged { key($0) == key($1) }
    }
}

// MARK: - First Methods

extension Async.Stream {
    /// Returns only the first element.
    ///
    /// ## Usage
    /// ```swift
    /// let first = stream.first()
    /// for await value in first { print(value) }  // prints one element
    /// ```
    ///
    /// - Returns: A stream that emits only the first element.
    public func first() -> Self {
        prefix(1)
    }

    /// Returns only the first element matching predicate.
    ///
    /// ## Usage
    /// ```swift
    /// let firstEven = numbers.first { $0 % 2 == 0 }
    /// ```
    ///
    /// - Parameter predicate: A function to test elements.
    /// - Returns: A stream that emits the first matching element.
    public func first(
        where predicate: @escaping @Sendable (Element) -> Bool
    ) -> Self {
        filter(predicate).first()
    }
}
