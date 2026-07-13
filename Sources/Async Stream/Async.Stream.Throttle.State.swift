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
public import Clock_Primitives
internal import Clocks_Dependencies
public import Ownership_Primitives

extension Async.Stream.Throttle {
    /// Internal state for throttle.
    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let duration: Duration

        @usableFromInline
        var lastEmitTime: Clock.`Any`<Duration>.Instant?

        @usableFromInline
        init(stream: Async.Stream<Element>, duration: Duration) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.duration = duration
        }
    }
}

extension Async.Stream.Throttle.State {
    @usableFromInline
    func next() async -> Element? {
        @Dependency(\.clock) var clock
        while true {
            guard let element = await box.next() else { return nil }

            let now = clock.now

            if let lastTime = lastEmitTime {
                let elapsed = lastTime.duration(to: now)
                if elapsed < duration {
                    // Too soon, skip this element
                    continue
                }
            }

            lastEmitTime = now
            return element
        }
    }
}
