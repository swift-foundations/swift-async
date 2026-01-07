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

extension Async.Array {
    /// A small array optimized for 0-1 elements.
    ///
    /// `Tiny` stores up to one element inline without heap allocation.
    /// Falls back to `Swift.Array` for two or more elements.
    ///
    /// This is useful for storing continuations where the common case
    /// is zero or one waiter.
    @usableFromInline
    struct Tiny<Element: Sendable>: Sendable {
        @usableFromInline
        var storage: Storage

        @inlinable
        init() {
            self.storage = .empty
        }
    }
}

// MARK: - Storage

extension Async.Array.Tiny {
    @usableFromInline
    enum Storage: Sendable {
        case empty
        case one(Element)
        case many([Element])
    }
}

// MARK: - Properties

extension Async.Array.Tiny {
    @inlinable
    var isEmpty: Bool {
        switch storage {
        case .empty:
            return true
        case .one:
            return false
        case .many(let array):
            return array.isEmpty
        }
    }

    @inlinable
    var count: Int {
        switch storage {
        case .empty:
            return 0
        case .one:
            return 1
        case .many(let array):
            return array.count
        }
    }

    @inlinable
    var first: Element? {
        switch storage {
        case .empty:
            return nil
        case .one(let element):
            return element
        case .many(let array):
            return array.first
        }
    }
}

// MARK: - Mutating Operations

extension Async.Array.Tiny {
    @inlinable
    mutating func append(_ element: Element) {
        switch storage {
        case .empty:
            storage = .one(element)
        case .one(let existing):
            storage = .many([existing, element])
        case .many(var array):
            storage = .empty // Avoid CoW
            array.append(element)
            storage = .many(array)
        }
    }

    @inlinable
    @discardableResult
    mutating func removeFirst() -> Element? {
        switch storage {
        case .empty:
            return nil
        case .one(let element):
            storage = .empty
            return element
        case .many(var array):
            storage = .empty // Avoid CoW
            guard !array.isEmpty else {
                return nil
            }
            let element = array.removeFirst()
            if array.count == 1 {
                storage = .one(array[0])
            } else if array.isEmpty {
                storage = .empty
            } else {
                storage = .many(array)
            }
            return element
        }
    }

    @inlinable
    mutating func removeAll() {
        storage = .empty
    }

    /// Remove the element with the given id.
    ///
    /// - Parameter predicate: A closure that returns `true` for the element to remove.
    /// - Returns: The removed element, or `nil` if not found.
    @inlinable
    @discardableResult
    mutating func removeFirst(where predicate: (Element) -> Bool) -> Element? {
        switch storage {
        case .empty:
            return nil
        case .one(let element):
            if predicate(element) {
                storage = .empty
                return element
            }
            return nil
        case .many(var array):
            storage = .empty // Avoid CoW
            if let index = array.firstIndex(where: predicate) {
                let element = array.remove(at: index)
                if array.count == 1 {
                    storage = .one(array[0])
                } else if array.isEmpty {
                    storage = .empty
                } else {
                    storage = .many(array)
                }
                return element
            }
            storage = .many(array)
            return nil
        }
    }
}

// MARK: - Iteration

extension Async.Array.Tiny {
    /// Iterate over all elements, removing them.
    @inlinable
    mutating func drain(_ body: (Element) -> Void) {
        switch storage {
        case .empty:
            break
        case .one(let element):
            storage = .empty
            body(element)
        case .many(let array):
            storage = .empty
            for element in array {
                body(element)
            }
        }
    }
}

// MARK: - Sequence

extension Async.Array.Tiny: Sequence {
    @usableFromInline
    struct Iterator: IteratorProtocol {
        @usableFromInline
        var storage: Storage
        @usableFromInline
        var index: Int = 0

        @usableFromInline
        init(storage: Storage) {
            self.storage = storage
        }

        @inlinable
        mutating func next() -> Element? {
            switch storage {
            case .empty:
                return nil
            case .one(let element):
                guard index == 0 else { return nil }
                index = 1
                return element
            case .many(let array):
                guard index < array.count else { return nil }
                defer { index += 1 }
                return array[index]
            }
        }
    }

    @inlinable
    func makeIterator() -> Iterator {
        Iterator(storage: storage)
    }
}
