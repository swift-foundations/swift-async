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
public import Column_Primitives
public import Buffer_Ring_Primitive
public import Storage_Contiguous_Primitives
internal import Buffer_Primitive
internal import Buffer_Ring_Bounded_Primitive
internal import Memory_Allocator_Primitive
internal import Memory_Heap_Primitives

extension Async.Stream.Replay {
    /// Subscription for replay stream.
    @usableFromInline
    actor Subscription {
        @usableFromInline
        var queue: Queue<Column.Ring<Element>>

        @usableFromInline
        var continuation: CheckedContinuation<Element?, Never>?

        @usableFromInline
        var finished: Bool

        @usableFromInline
        init(replay: sending [Element], finished: Bool) {
            self.queue = .init()
            for element in replay { self.queue.enqueue(element) }
            self.finished = finished
        }
    }
}

extension Async.Stream.Replay.Subscription {
    @usableFromInline
    nonisolated func receive(_ element: sending Element) {
        Task { await _receive(element) }
    }

    @usableFromInline
    func _receive(_ element: sending Element) {
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: element)
        } else {
            queue.enqueue(element)
        }
    }

    @usableFromInline
    nonisolated func finish() {
        Task { await _finish() }
    }

    @usableFromInline
    func _finish() {
        finished = true
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: nil)
        }
    }

    @usableFromInline
    func next() async -> Element? {
        if !queue.isEmpty {
            return queue.dequeue()!
        }

        if finished {
            return nil
        }

        return await withCheckedContinuation { cont in
            continuation = cont
        }
    }
}
