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
public import Buffer_Primitives

extension Async.Stream.Buffer {
    /// Namespace for count-based buffering.
    public enum Count {}
}

extension Async.Stream.Buffer.Count {
    /// Internal state for count-based buffering.
    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let count: Int

        @usableFromInline
        var ring: Buffer.Ring.Fixed<Element>

        @usableFromInline
        init(stream: Async.Stream<Element>, count: Int) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.count = max(1, count)
            self.ring = Buffer.Ring.Fixed<Element>(capacity: count)
        }
    }
}

extension Async.Stream.Buffer.Count.State {
    @usableFromInline
    func next() async -> [Element]? {
        while true {
            guard let element = await box.next() else {
                // Upstream complete - emit remaining if any
                if ring.count > 0 {
                    var result: [Element] = []
                    result.reserveCapacity(ring.count)
                    ring.drain { result.append($0) }
                    return result
                }
                return nil
            }

            _ = ring.push(element)

            if ring.count >= count {
                var result: [Element] = []
                result.reserveCapacity(ring.count)
                ring.drain { result.append($0) }
                return result
            }
        }
    }
}
