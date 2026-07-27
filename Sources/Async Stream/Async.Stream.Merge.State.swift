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

extension Async.Stream.Merge {
    /// Internal state for merge operations.
    @usableFromInline
    actor State {
        @usableFromInline
        var queue: Queue<Element> = .init()

        @usableFromInline
        var continuation: CheckedContinuation<Element?, Never>?

        @usableFromInline
        var completed = 0

        @usableFromInline
        var cancelled = false

        @usableFromInline
        let streamCount = 2

        @usableFromInline
        init() {}
    }
}

extension Async.Stream.Merge.State {
    @usableFromInline
    func send(_ element: sending Element) {
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: element)
        } else {
            queue.enqueue(element)
        }
    }

    @usableFromInline
    func complete() {
        completed += 1
        if completed >= streamCount, let cont = continuation {
            continuation = nil
            cont.resume(returning: nil)
        }
    }

    @usableFromInline
    func receive() async -> Element? {
        if !queue.isEmpty {
            return queue.dequeue()!
        }

        if cancelled || completed >= streamCount {
            return nil
        }

        // F-001: a bare `withCheckedContinuation` here is not cancellation-cooperative —
        // if the consuming task is cancelled while suspended, nothing ever resumes the
        // continuation and the consumer hangs permanently. `withTaskCancellationHandler`
        // resumes it with `nil` on cancellation instead.
        //
        // Race note: `onCancel` runs concurrently with `operation` and may fire before
        // `registerContinuation(_:)` has stored the continuation (if the task was already
        // cancelled, or is cancelled in the narrow window before storage). We close that
        // window by re-checking `Task.isCancelled` *inside* `registerContinuation(_:)`:
        // that check runs as a continuation of the caller's task (via the `await` into
        // this actor), so it observes the same cancellation flag `onCancel` reacted to,
        // regardless of which side of the actor's serial queue ran first. Either the
        // cancellation handler resumes the continuation (already-stored case), or
        // `registerContinuation` sees the cancellation itself and resumes immediately
        // instead of storing (not-yet-stored case) — exactly one resume either way.
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
            cancelled = true
            cont.resume(returning: nil)
            return
        }
        continuation = cont
    }

    @usableFromInline
    func cancelPendingReceive() {
        cancelled = true
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: nil)
        }
    }
}
