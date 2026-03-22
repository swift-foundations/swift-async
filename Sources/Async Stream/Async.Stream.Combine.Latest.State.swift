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

extension Async.Stream.Combine {
    /// Internal state for combine latest operations.
    @usableFromInline
    actor State<A: Sendable, B: Sendable> {
        @usableFromInline
        var latestA: A?

        @usableFromInline
        var latestB: B?

        @usableFromInline
        var queue: Queue<(A, B)> = .init()

        @usableFromInline
        var continuation: CheckedContinuation<(A, B)?, Never>?

        @usableFromInline
        var aComplete = false

        @usableFromInline
        var bComplete = false

        @usableFromInline
        init() {}
    }
}

extension Async.Stream.Combine.State {
    @usableFromInline
    func updateA(_ value: sending A) {
        latestA = value
        emitIfPossible()
    }

    @usableFromInline
    func updateB(_ value: sending B) {
        latestB = value
        emitIfPossible()
    }

    @usableFromInline
    func emitIfPossible() {
        guard let a = latestA, let b = latestB else { return }

        if let cont = continuation {
            continuation = nil
            cont.resume(returning: (a, b))
        } else {
            queue.enqueue((a, b))
        }
    }

    @usableFromInline
    func completeA() {
        aComplete = true
        checkComplete()
    }

    @usableFromInline
    func completeB() {
        bComplete = true
        checkComplete()
    }

    @usableFromInline
    func checkComplete() {
        if aComplete && bComplete, let cont = continuation {
            continuation = nil
            cont.resume(returning: nil)
        }
    }

    @usableFromInline
    func receive() async -> (A, B)? {
        if !queue.isEmpty {
            return queue.dequeue()!
        }

        if aComplete && bComplete {
            return nil
        }

        return await withCheckedContinuation { cont in
            continuation = cont
        }
    }
}
