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
    /// Buffer operations namespace.
    public struct Buffer: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {
    /// Buffer accessor for buffer operations.
    public var buffer: Buffer { Buffer(base: self) }
}

// MARK: - Buffer by Count

extension Async.Stream.Buffer {
    /// Collects elements into arrays of fixed size.
    ///
    /// ## Usage
    /// ```swift
    /// let batches = stream.buffer.count(5)
    /// // Emits [1,2,3,4,5], [6,7,8,9,10], ...
    /// ```
    ///
    /// - Parameter count: Number of elements per batch.
    /// - Returns: A stream of element arrays.
    public func count(_ count: Int) -> Async.Stream<[Element]> {
        Async.Stream<[Element]> { [base] in
            let state = Async.Stream<Element>.Buffer.Count.State(stream: base, count: count)
            return Async.Stream<[Element]>.Iterator {
                await state.next()
            }
        }
    }
}

// MARK: - Buffer by Time

extension Async.Stream.Buffer {
    /// Collects elements over a time window.
    ///
    /// ## Usage
    /// ```swift
    /// let batches = stream.buffer.time(.seconds(1))
    /// // Emits array of elements received each second
    /// ```
    ///
    /// - Parameter duration: The time window for collection.
    /// - Returns: A stream of element arrays.
    public func time(_ duration: Duration) -> Async.Stream<[Element]> {
        Async.Stream<[Element]> { [base] in
            let state = Async.Stream<Element>.Buffer.Time.State(stream: base, duration: duration)
            return Async.Stream<[Element]>.Iterator {
                await state.next()
            }
        }
    }
}

// MARK: - Buffer by Count or Time

extension Async.Stream.Buffer {
    /// Collects elements until count reached or time elapsed.
    ///
    /// Emits whichever condition is met first.
    ///
    /// ## Usage
    /// ```swift
    /// let batches = stream.buffer.window(count: 100, time: .seconds(1))
    /// // Emits when 100 elements collected OR 1 second passes
    /// ```
    ///
    /// - Parameters:
    ///   - count: Maximum elements per batch.
    ///   - time: Maximum time window.
    /// - Returns: A stream of element arrays.
    public func window(count: Int, time duration: Duration) -> Async.Stream<[Element]> {
        Async.Stream<[Element]> { [base] in
            let state = Async.Stream<Element>.Buffer.Window.State(stream: base, count: count, duration: duration)
            return Async.Stream<[Element]>.Iterator {
                await state.next()
            }
        }
    }
}
