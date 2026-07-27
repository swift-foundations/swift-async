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

extension Async.Stream.Last {
    /// Internal state for last.
    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        var lastElement: Element?

        @usableFromInline
        var done: Bool = false

        @usableFromInline
        init(stream: Async.Stream<Element>) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
        }
    }
}

extension Async.Stream.Last.State {
    @usableFromInline
    func next() async -> Element? {
        if done { return nil }

        // Consume entire stream
        while let element = await box.next() {
            lastElement = element
        }

        done = true
        return lastElement
    }
}
