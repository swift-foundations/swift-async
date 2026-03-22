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
    /// Internal actor to hold sequence iteration state.
    @usableFromInline
    actor State {
        @usableFromInline
        var elements: [Element]

        @usableFromInline
        var index: Int = 0

        @usableFromInline
        init(_ elements: [Element]) {
            self.elements = elements
        }
    }
}

extension Async.Stream.State {
    @usableFromInline
    func next() -> Element? {
        guard index < elements.count else { return nil }
        defer { index += 1 }
        return elements[index]
    }
}
