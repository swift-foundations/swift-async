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

extension Async.Stream.WithLatestFrom {
    /// Internal state for withLatestFrom.
    @usableFromInline
    actor State<Other: Sendable> {
        @usableFromInline
        var latestOther: Other?

        @usableFromInline
        var sourceBox: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        var otherTask: Task<Void, Never>?

        @usableFromInline
        var started: Bool = false

        @usableFromInline
        let other: Async.Stream<Other>

        @usableFromInline
        init(source: Async.Stream<Element>, other: Async.Stream<Other>) {
            self.sourceBox = Async.Stream<Element>.Iterator.Box(source.makeAsyncIterator())
            self.other = other
        }
    }
}

extension Async.Stream.WithLatestFrom.State {
    @usableFromInline
    func startOtherTask() {
        guard !started else { return }
        started = true
        otherTask = Task {
            for await element in other {
                await self.updateLatestOther(element)
            }
        }
    }

    @usableFromInline
    func updateLatestOther(_ element: sending Other) async {
        latestOther = element
    }

    @usableFromInline
    func next() async -> (Element, Other)? {
        startOtherTask()

        while true {
            guard let element = await sourceBox.next() else {
                otherTask?.cancel()
                return nil
            }

            // Only emit if we have a latest from other
            if let other = latestOther {
                return (element, other)
            }
            // Skip until we have a value from other
        }
    }
}
