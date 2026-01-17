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
public import Reference_Primitives

extension Async.Stream.Prefix {
    /// Internal state for prefix while.
    @usableFromInline
    actor While {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let predicate: @Sendable (Element) -> Bool

        @usableFromInline
        var done: Bool = false

        @usableFromInline
        init(stream: Async.Stream<Element>, predicate: @escaping @Sendable (Element) -> Bool) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.predicate = predicate
        }
    }
}

extension Async.Stream.Prefix.While {
    @usableFromInline
    func next() async -> Element? {
        if done { return nil }
        guard let element = await box.next() else { return nil }
        if predicate(element) {
            return element
        } else {
            done = true
            return nil
        }
    }
}
