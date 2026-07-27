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
public import Ownership_Primitives

extension Async.Stream {
    /// Distinct operations namespace.
    public struct Distinct: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {
    /// Distinct accessor for distinct operations.
    public var distinct: Distinct { Distinct(base: self) }
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

// MARK: - UntilChanged Methods

extension Async.Stream.Distinct where Element: Equatable {
    /// Suppresses consecutive duplicate elements.
    ///
    /// ## Usage
    /// ```swift
    /// let distinct = [1, 1, 2, 2, 2, 3, 1].asStream().distinct.untilChanged()
    /// // Emits: 1, 2, 3, 1
    /// ```
    ///
    /// - Returns: A stream without consecutive duplicates.
    public func untilChanged() -> Async.Stream<Element> {
        untilChanged(==)
    }
}

extension Async.Stream.Distinct {
    /// Suppresses consecutive elements that compare equal.
    ///
    /// ## Usage
    /// ```swift
    /// let distinct = users.distinct.untilChanged { $0.id == $1.id }
    /// ```
    ///
    /// - Parameter areEqual: A function to compare consecutive elements.
    /// - Returns: A stream without consecutive duplicates.
    public func untilChanged(
        _ areEqual: @escaping @Sendable (Element, Element) -> Bool
    ) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Distinct.State(stream: base, areEqual: areEqual)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }

    /// Suppresses consecutive elements with equal key values.
    ///
    /// ## Usage
    /// ```swift
    /// let distinct = users.distinct.untilChanged { $0.id }
    /// ```
    ///
    /// - Parameter key: A function to extract the key to compare.
    /// - Returns: A stream without consecutive duplicates by key.
    public func untilChanged<Key: Equatable & Sendable>(
        by key: @escaping @Sendable (Element) -> Key
    ) -> Async.Stream<Element> {
        untilChanged { key($0) == key($1) }
    }
}
