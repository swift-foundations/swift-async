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

extension Async.Stream.Repeat {
    /// Internal state for repeat stream.
    @usableFromInline
    actor State {
        @usableFromInline
        let value: Element

        @usableFromInline
        var remaining: Int?

        @usableFromInline
        init(value: sending Element, count: Int?) {
            self.value = value
            self.remaining = count
        }
    }
}

extension Async.Stream.Repeat.State {
    @usableFromInline
    func next() async -> Element? {
        if Task.isCancelled { return nil }
        if let r = remaining {
            if r <= 0 { return nil }
            remaining = r - 1
        }
        return value
    }
}
