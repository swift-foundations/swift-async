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
public import Buffer_Ring_Primitives
internal import Cardinal_Primitives

extension Async.Stream.Buffer.Count {
    /// Internal state for count-based buffering.
    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let count: Index<Element>.Count

        @usableFromInline
        var ring: Buffer<Storage<Element>.Heap>.Ring.Bounded

        @usableFromInline
        init(stream: Async.Stream<Element>, count: Int) {
            let typedCount = try! Index<Element>.Count(max(1, count))
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.count = typedCount
            self.ring = Buffer<Storage<Element>.Heap>.Ring.Bounded(minimumCapacity: typedCount)
        }
    }
}

extension Async.Stream.Buffer.Count.State {
    @usableFromInline
    func next() async -> [Element]? {
        while true {
            guard let element = await box.next() else {
                // Upstream complete - emit remaining if any
                if ring.count > .zero {
                    var result: [Element] = []
                    ring.drain { result.append($0) }
                    return result
                }
                return nil
            }

            ring.push.back(element)

            if ring.count >= count {
                var result: [Element] = []
                ring.drain { result.append($0) }
                return result
            }
        }
    }
}
