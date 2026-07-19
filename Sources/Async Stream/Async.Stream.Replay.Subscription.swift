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
internal import Buffer_Primitive
internal import Buffer_Ring_Bounded_Primitive
public import Buffer_Ring_Primitive
public import Column_Primitives
internal import Memory_Allocator_Primitive
internal import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives

extension Async.Stream.Replay {
    /// Subscription for replay stream.
    @usableFromInline
    actor Subscription {
        @usableFromInline
        var queue: Queue<Element>

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

        // F-001: a bare `withCheckedContinuation` here is not cancellation-cooperative —
        // if the consuming task is cancelled while suspended, nothing ever resumes the
        // continuation and the consumer hangs permanently. `withTaskCancellationHandler`
        // resumes it with `nil` (and marks the subscription `finished`) on cancellation.
        //
        // Race note: `onCancel` runs concurrently with `operation` and may fire before
        // `registerContinuation(_:)` has stored the continuation. We close that window by
        // re-checking `Task.isCancelled` *inside* `registerContinuation(_:)`: that check
        // runs as a continuation of the caller's task (via the `await` into this actor),
        // so it observes the same cancellation flag `onCancel` reacted to, regardless of
        // which side of the actor's serial queue ran first. Either the cancellation
        // handler resumes the continuation (already-stored case), or `registerContinuation`
        // sees the cancellation itself and resumes immediately instead of storing
        // (not-yet-stored case) — exactly one resume either way.
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Element?, Never>) in
                registerContinuation(cont)
            }
        } onCancel: {
            Task { await self.cancelPendingReceive() }
        }
    }

    @usableFromInline
    func registerContinuation(_ cont: CheckedContinuation<Element?, Never>) {
        if Task.isCancelled {
            finished = true
            cont.resume(returning: nil)
            return
        }
        continuation = cont
    }

    @usableFromInline
    func cancelPendingReceive() {
        finished = true
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: nil)
        }
    }
}
