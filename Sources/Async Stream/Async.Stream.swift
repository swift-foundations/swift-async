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

extension Async {
    /// A composable asynchronous stream of values.
    ///
    /// `Stream` provides a unified concrete type for composing asynchronous
    /// sequences with operators like `merge`, `zip`, `combineLatest`, `debounce`, etc.
    ///
    /// Unlike raw `AsyncSequence`, `Stream` is a concrete type that can be
    /// stored, passed around, and composed without type erasure or type explosion.
    ///
    /// ## Pattern
    /// - Create streams from various sources (intervals, channels, broadcasts)
    /// - Compose streams using operators (merge, zip, map, filter)
    /// - Consume streams with `for await` or terminal operators
    ///
    /// ## Usage
    /// ```swift
    /// // Create streams
    /// let ticks = Async.Stream.interval(.seconds(1))
    /// let messages = Async.Stream(from: broadcast)
    ///
    /// // Compose - all return the same concrete type
    /// let combined = Async.Stream.merge(
    ///     ticks.map { "Tick \($0)" },
    ///     messages
    /// )
    ///
    /// // Consume
    /// for await item in combined {
    ///     print(item)
    /// }
    /// ```
    ///
    /// ## Thread Safety
    /// Streams are `Sendable` and can be shared across tasks.
    /// Each iterator maintains independent state.
    public struct Stream<Element: Sendable>: AsyncSequence, Sendable {
        public typealias AsyncIterator = Iterator

        @usableFromInline
        let _makeIterator: @Sendable () -> Iterator

        /// Creates a stream from an iterator factory.
        ///
        /// This is the fundamental initializer. Most users should use
        /// the convenience initializers or static factory methods.
        ///
        /// - Parameter makeIterator: A sendable closure that creates iterators.
        @inlinable
        public init(_ makeIterator: @escaping @Sendable () -> Iterator) {
            self._makeIterator = makeIterator
        }
    }
}

// MARK: - Initializers

extension Async.Stream {
    /// Creates a stream from an existing AsyncSequence.
    ///
    /// ## Usage
    /// ```swift
    /// let asyncSeq = someAsyncSequence()
    /// let stream = Async.Stream(asyncSeq)
    /// ```
    ///
    /// - Parameter sequence: The async sequence to wrap.
    /// - Returns: A stream that emits the sequence's elements.
    public init<S: AsyncSequence & Sendable>(_ sequence: S) where S.Element == Element {
        self.init {
            // We need to create mutable state that can be captured
            let box = Async.Stream<Element>.Iterator.Box(sequence.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }
}

// MARK: - AsyncSequence Conformance

extension Async.Stream {
    @inlinable
    public func makeAsyncIterator() -> Iterator {
        _makeIterator()
    }
}

// MARK: - Basic Constructors

extension Async.Stream {
    /// Creates an empty stream that immediately completes.
    ///
    /// ## Usage
    /// ```swift
    /// let empty = Async.Stream<Int>.empty
    /// for await _ in empty { } // Completes immediately
    /// ```
    public static var empty: Self {
        Self { Iterator { nil } }
    }

    /// Creates a stream that never emits.
    ///
    /// Suspends indefinitely until the consuming task is cancelled,
    /// at which point the stream completes by returning `nil`.
    ///
    /// ## Usage
    /// ```swift
    /// let never = Async.Stream<Int>.never
    /// // Suspends until cancelled
    /// ```
    public static var never: Self {
        Self {
            Iterator {
                try? await Task.sleep(for: .seconds(Int64.max))
                return nil
            }
        }
    }

    /// Creates a stream that emits a single value and completes.
    ///
    /// ## Usage
    /// ```swift
    /// let single = Async.Stream.just(42)
    /// for await value in single {
    ///     print(value)  // Prints: 42
    /// }
    /// ```
    ///
    /// - Parameter value: The single value to emit.
    /// - Returns: A stream that emits the value once.
    public static func just(_ value: Element) -> Self {
        from([value])
    }

    /// Creates a stream from a sequence.
    ///
    /// Emits each element of the sequence in order.
    ///
    /// ## Usage
    /// ```swift
    /// let numbers = Async.Stream.from([1, 2, 3])
    /// for await n in numbers {
    ///     print(n)  // Prints: 1, 2, 3
    /// }
    /// ```
    ///
    /// - Parameter sequence: The sequence to emit.
    /// - Returns: A stream that emits each element.
    public static func from<S: Sequence & Sendable>(_ sequence: S) -> Self where S.Element == Element {
        Self {
            let state = State(Array(sequence))
            return Iterator {
                await state.next()
            }
        }
    }
}
