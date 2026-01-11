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

extension Async.Stream.Sample {
    /// Internal state for sample.
    @usableFromInline
    actor State<Trigger: Sendable> {
        @usableFromInline
        var latest: Element?

        @usableFromInline
        var sourceTask: Task<Void, Never>?

        @usableFromInline
        var triggerBox: Async.Stream<Element>.Iterator.Box<Async.Stream<Trigger>.Iterator>

        @usableFromInline
        var sourceDone: Bool = false

        @usableFromInline
        var started: Bool = false

        @usableFromInline
        let source: Async.Stream<Element>

        @usableFromInline
        init(source: Async.Stream<Element>, trigger: Async.Stream<Trigger>) {
            self.source = source
            self.triggerBox = Async.Stream<Element>.Iterator.Box(trigger.makeAsyncIterator())
        }
    }
}

extension Async.Stream.Sample.State {
    @usableFromInline
    func startSourceTask() {
        guard !started else { return }
        started = true
        sourceTask = Task {
            for await element in source {
                await self.updateLatest(element)
            }
            await self.markSourceDone()
        }
    }

    @usableFromInline
    func updateLatest(_ element: sending Element) async {
        latest = element
    }

    @usableFromInline
    func markSourceDone() async {
        sourceDone = true
    }

    @usableFromInline
    func next() async -> Element? {
        startSourceTask()

        while true {
            // Wait for next trigger
            guard await triggerBox.next() != nil else {
                sourceTask?.cancel()
                return nil
            }

            // Return latest if we have one
            if let value = latest {
                return value
            }

            // No value yet, but source might still produce
            if sourceDone {
                return nil
            }
        }
    }
}
