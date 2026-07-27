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

extension Async.Stream.Scan {
    /// Internal state for scan.
    @usableFromInline
    actor State<Result: Sendable> {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let accumulator: @Sendable (Result, Element) -> Result

        @usableFromInline
        var state: Result

        @usableFromInline
        init(stream: Async.Stream<Element>, initial: sending Result, accumulator: @escaping @Sendable (Result, Element) -> Result) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.state = initial
            self.accumulator = accumulator
        }
    }
}

extension Async.Stream.Scan.State {
    @usableFromInline
    func next() async -> Result? {
        guard let element = await box.next() else { return nil }
        state = accumulator(state, element)
        return state
    }
}
