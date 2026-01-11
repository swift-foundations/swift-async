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

extension Async.Stream.Merge {
    /// Internal state for merge operations.
    @usableFromInline
    actor State {
        @usableFromInline
        var buffer: [Element] = []

        @usableFromInline
        var continuation: CheckedContinuation<Element?, Never>?

        @usableFromInline
        var completed = 0

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
            buffer.append(element)
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
        if !buffer.isEmpty {
            return buffer.removeFirst()
        }

        if completed >= streamCount {
            return nil
        }

        return await withCheckedContinuation { cont in
            continuation = cont
        }
    }
}
