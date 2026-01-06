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
        private let _mutex: Mutex<Storage>

        /// Creates an empty queue.
        public init() {
            self._mutex = Mutex(Storage())
        }

        /// Adds an element to the back of the queue.
        ///
        /// - Parameter element: The element to add.
        /// - Complexity: O(1) amortized.
        public func enqueue(_ element: Element) {
            _mutex.withLock { storage in
                storage.buffer.append(element)
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
            _mutex.withLock { $0.buffer.isEmpty }
        }

        /// The number of elements in the queue.
        public var count: Int {
            _mutex.withLock { $0.buffer.count }
        }
    }
}

// MARK: - Storage

extension Runtime.Mutex.Queue {
    struct Storage {
        var buffer: [Element]
        var headIndex: Int

        init() {
            self.buffer = []
            self.headIndex = 0
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
        /// - Complexity: O(1) amortized (compacts buffer when head exceeds half).
        public func one() -> Element? {
            queue._mutex.withLock { storage in
                guard storage.headIndex < storage.buffer.count else {
                    return nil
                }
                let element = storage.buffer[storage.headIndex]
                storage.headIndex += 1

                // Compact when head exceeds half the buffer
                if storage.headIndex > storage.buffer.count / 2 && storage.headIndex > 16 {
                    storage.buffer.removeFirst(storage.headIndex)
                    storage.headIndex = 0
                }

                return element
            }
        }

        /// Removes and returns all elements.
        ///
        /// - Returns: All elements in FIFO order, or empty array if queue is empty.
        /// - Complexity: O(n) where n is the number of elements.
        public func all() -> [Element] {
            queue._mutex.withLock { storage in
                guard storage.headIndex < storage.buffer.count else {
                    return []
                }
                let elements = Array(storage.buffer[storage.headIndex...])
                storage.buffer.removeAll(keepingCapacity: true)
                storage.headIndex = 0
                return elements
            }
        }

        /// Drains all elements into an existing buffer.
        ///
        /// More efficient than `all()` when reusing a pre-allocated buffer.
        /// - Parameter buffer: Buffer to append elements to.
        /// - Returns: Number of elements drained.
        /// - Complexity: O(n) where n is the number of elements.
        @discardableResult
        public func all(into buffer: inout [Element]) -> Int {
            queue._mutex.withLock { storage in
                guard storage.headIndex < storage.buffer.count else {
                    return 0
                }
                let count = storage.buffer.count - storage.headIndex
                buffer.append(contentsOf: storage.buffer[storage.headIndex...])
                storage.buffer.removeAll(keepingCapacity: true)
                storage.headIndex = 0
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
