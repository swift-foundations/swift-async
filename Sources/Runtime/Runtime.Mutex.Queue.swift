// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-runtime open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-runtime project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import StandardsCollections
import Synchronization

extension Runtime.Mutex {
    /// A thread-safe FIFO queue protected by a mutex.
    ///
    /// Queue provides a simple, policy-free buffer for multi-producer
    /// single-consumer (MPSC) scenarios. All operations are O(1) amortized.
    ///
    /// ## No Lifecycle Policy
    /// This queue has no shutdown semantics - it's a pure data structure.
    /// Higher layers compose shutdown behavior using `Kernel.Atomic.Flag`
    /// alongside this queue.
    ///
    /// ## Usage
    /// ```swift
    /// let queue = Runtime.Mutex.Queue<Int>()
    ///
    /// // Producers (any thread)
    /// queue.enqueue(1)
    /// queue.enqueue(2)
    ///
    /// // Consumer (single thread)
    /// if let item = queue.dequeue.one() {
    ///     // Process item
    /// }
    ///
    /// // Drain all
    /// let items = queue.dequeue.all()
    /// ```
    ///
    /// ## Thread Safety
    /// All operations are protected by an internal mutex.
    /// Uses `@unchecked Sendable` because internal state is protected
    /// by mutex synchronization.
    public final class Queue<Element: Sendable>: @unchecked Sendable {
        private let _mutex: Mutex<Deque<Element>>

        /// Creates an empty queue.
        public init() {
            self._mutex = Mutex(Deque())
        }

        /// Adds an element to the back of the queue.
        ///
        /// - Parameter element: The element to add.
        /// - Complexity: O(1) amortized.
        public func enqueue(_ element: Element) {
            _mutex.withLock { buffer in
                buffer.push.back(element)
            }
        }

        /// Accessor for dequeue operations.
        ///
        /// Use `dequeue.one()` for single elements or `dequeue.all()` to drain.
        public var dequeue: Dequeue {
            Dequeue(queue: self)
        }

        /// Whether the queue is empty.
        public var isEmpty: Bool {
            _mutex.withLock { $0.isEmpty }
        }

        /// The number of elements in the queue.
        public var count: Int {
            _mutex.withLock { $0.count }
        }
    }
}

// MARK: - Dequeue Accessor

extension Runtime.Mutex.Queue {
    /// Accessor for dequeue operations.
    ///
    /// Provides `one()` for single-element dequeue and `all()` for draining.
    /// Supports `callAsFunction()` for convenient single-element access.
    public struct Dequeue {
        let queue: Runtime.Mutex.Queue<Element>

        init(queue: Runtime.Mutex.Queue<Element>) {
            self.queue = queue
        }

        /// Removes and returns the front element, or `nil` if empty.
        ///
        /// - Returns: The front element, or `nil` if the queue is empty.
        /// - Complexity: O(1) amortized.
        public func one() -> Element? {
            queue._mutex.withLock { buffer in
                buffer.take.front
            }
        }

        /// Removes and returns all elements.
        ///
        /// - Returns: All elements in FIFO order, or empty array if queue is empty.
        /// - Complexity: O(n) where n is the number of elements.
        public func all() -> [Element] {
            queue._mutex.withLock { buffer in
                var elements: [Element] = []
                elements.reserveCapacity(buffer.count)
                while let element = buffer.take.front {
                    elements.append(element)
                }
                return elements
            }
        }

        /// Drains all elements into an existing buffer.
        ///
        /// More efficient than `all()` when reusing a pre-allocated buffer.
        /// - Parameter target: Buffer to append elements to.
        /// - Returns: Number of elements drained.
        /// - Complexity: O(n) where n is the number of elements.
        @discardableResult
        public func all(into target: inout [Element]) -> Int {
            queue._mutex.withLock { buffer in
                var count = 0
                while let element = buffer.take.front {
                    target.append(element)
                    count += 1
                }
                return count
            }
        }

        /// Removes and returns the front element, or `nil` if empty.
        ///
        /// Convenience for `one()`.
        public func callAsFunction() -> Element? {
            one()
        }
    }
}
