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
    /// Namespace for unfold operations.
    public enum Unfold {}
}

extension Async.Stream.Unfold {
    /// Internal state for unfold stream.
    @usableFromInline
    actor State<S: Sendable> {
        @usableFromInline
        var state: S

        @usableFromInline
        let nextFn: @Sendable (S) async -> (Element, S)?

        @usableFromInline
        init(initial: S, next: @escaping @Sendable (S) async -> (Element, S)?) {
            self.state = initial
            self.nextFn = next
        }
    }
}

extension Async.Stream.Unfold.State {
    @usableFromInline
    func next() async -> Element? {
        if Task.isCancelled { return nil }
        guard let (element, newState) = await self.nextFn(state) else { return nil }
        state = newState
        return element
    }
}

// MARK: - Unfold Method

extension Async.Stream {
    /// Creates a stream by repeatedly applying a function to state.
    ///
    /// Similar to `sequence(state:next:)` but async and returns a concrete Stream type.
    ///
    /// ## Usage
    /// ```swift
    /// // Fibonacci sequence
    /// let fib = Async.Stream.unfold((0, 1)) { state in
    ///     let value = state.0
    ///     return (value, (state.1, state.0 + state.1))
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - initial: The initial state.
    ///   - next: A function that produces an element and next state, or nil to complete.
    /// - Returns: A stream of unfolded elements.
    public static func unfold<State: Sendable>(
        _ initial: State,
        _ next: @escaping @Sendable (State) async -> (Element, State)?
    ) -> Self {
        Self {
            let state = Async.Stream<Element>.Unfold.State(initial: initial, next: next)
            return Iterator {
                await state.next()
            }
        }
    }
}

// MARK: - Generate Method

extension Async.Stream {
    /// Creates a stream from a generator function.
    ///
    /// The generator is called repeatedly to produce elements.
    /// Return `nil` to complete the stream.
    ///
    /// ## Usage
    /// ```swift
    /// var count = 0
    /// let stream = Async.Stream.generate {
    ///     count += 1
    ///     return count <= 5 ? count : nil
    /// }
    /// // Emits: 1, 2, 3, 4, 5
    /// ```
    ///
    /// - Parameter generator: A function that produces elements.
    /// - Returns: A stream that emits generated elements.
    public static func generate(
        _ generator: @escaping @Sendable () async -> Element?
    ) -> Self {
        Self {
            Iterator {
                if Task.isCancelled { return nil }
                return await generator()
            }
        }
    }
}
