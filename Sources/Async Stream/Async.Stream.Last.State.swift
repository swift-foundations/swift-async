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
    /// Namespace for last operation.
    public enum Last {}
}

extension Async.Stream.Last {
    /// Internal state for last.
    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        var lastElement: Element?

        @usableFromInline
        var done: Bool = false

        @usableFromInline
        init(stream: Async.Stream<Element>) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
        }
    }
}

extension Async.Stream.Last.State {
    @usableFromInline
    func next() async -> Element? {
        if done { return nil }

        // Consume entire stream
        while let element = await box.next() {
            lastElement = element
        }

        done = true
        return lastElement
    }
}

// MARK: - Last Methods

extension Async.Stream {
    /// Collects and emits only the last element.
    ///
    /// Note: This consumes the entire stream before emitting.
    ///
    /// ## Usage
    /// ```swift
    /// let last = stream.last()
    /// ```
    ///
    /// - Returns: A stream that emits only the last element.
    public func last() -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Last.State(stream: self)
            return Iterator {
                await state.next()
            }
        }
    }

    /// Collects and emits only the last element matching predicate.
    ///
    /// - Parameter predicate: A function to test elements.
    /// - Returns: A stream that emits the last matching element.
    public func last(
        where predicate: @escaping @Sendable (Element) -> Bool
    ) -> Self {
        filter(predicate).last()
    }
}
