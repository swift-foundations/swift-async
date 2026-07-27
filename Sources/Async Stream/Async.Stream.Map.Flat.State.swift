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

extension Async.Stream.Map.Flat {
    /// Internal state for flat map.
    @usableFromInline
    actor State<U: Sendable> {
        @usableFromInline
        let outerBox: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let transform: Transform

        @usableFromInline
        var innerBox: Async.Stream<Element>.Iterator.Box<Async.Stream<U>.Iterator>?

        @usableFromInline
        enum Transform {
            case sync(@Sendable (Element) -> Async.Stream<U>)
            case async(@Sendable (Element) async -> Async.Stream<U>)
        }

        @usableFromInline
        init(stream: Async.Stream<Element>, transform: Transform) {
            self.outerBox = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.transform = transform
        }
    }
}

extension Async.Stream.Map.Flat.State {
    @usableFromInline
    func next() async -> U? {
        while true {
            // Try to get from current inner stream
            if let inner = innerBox, let element = await inner.next() {
                return element
            }

            // Get next outer element
            guard let outerElement = await outerBox.next() else {
                return nil
            }

            // Create new inner stream
            let innerStream: Async.Stream<U>
            switch transform {
            case .sync(let f): innerStream = f(outerElement)
            case .async(let f): innerStream = await f(outerElement)
            }
            innerBox = Async.Stream<Element>.Iterator.Box(innerStream.makeAsyncIterator())
        }
    }
}
