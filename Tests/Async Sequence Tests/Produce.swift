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

/// A simple async sequence that emits elements from an array.
///
/// Used as a test fixture to avoid depending on `Async.Stream` or stdlib sequences
/// whose `map`/`filter` overloads could interfere with overload resolution.
struct Produce<Element: Sendable>: AsyncSequence, Sendable {
    let values: [Element]

    init(_ values: [Element]) {
        self.values = values
    }

    struct Iterator: AsyncIteratorProtocol {
        var index: Int = 0
        let values: [Element]

        mutating func next(
            isolation actor: isolated (any Actor)? = #isolation
        ) async -> Element? {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(values: values)
    }
}
