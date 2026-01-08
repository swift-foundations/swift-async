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

extension Async.Stream.Replay {
    /// Subscription for replay stream.
    @usableFromInline
    actor Subscription {
        @usableFromInline
        var buffer: [Element]

        @usableFromInline
        var continuation: CheckedContinuation<Element?, Never>?

        @usableFromInline
        var finished: Bool

        @usableFromInline
        init(replay: [Element], finished: Bool) {
            self.buffer = replay
            self.finished = finished
        }
    }
}

extension Async.Stream.Replay.Subscription {
    @usableFromInline
    nonisolated func receive(_ element: Element) {
        Task { await _receive(element) }
    }

    @usableFromInline
    func _receive(_ element: Element) {
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: element)
        } else {
            buffer.append(element)
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
        if !buffer.isEmpty {
            return buffer.removeFirst()
        }

        if finished {
            return nil
        }

        return await withCheckedContinuation { cont in
            continuation = cont
        }
    }
}
