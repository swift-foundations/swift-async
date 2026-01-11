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

extension Async.Stream.CombineLatest {
    /// Internal state for combineLatest operations.
    @usableFromInline
    actor State<A: Sendable, B: Sendable> {
        @usableFromInline
        var latestA: A?

        @usableFromInline
        var latestB: B?

        @usableFromInline
        var buffer: [(A, B)] = []

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

extension Async.Stream.CombineLatest.State {
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
            buffer.append((a, b))
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
        if !buffer.isEmpty {
            return buffer.removeFirst()
        }

        if aComplete && bComplete {
            return nil
        }

        return await withCheckedContinuation { cont in
            continuation = cont
        }
    }
}
