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
public import Clocks_Dependency
public import Ownership_Primitives

extension Async.Stream {
    /// Namespace for throttle operations.
    public enum Throttle {}
}

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

// MARK: - Throttle Method

extension Async.Stream {
    /// Limits emissions to at most one per duration.
    ///
    /// Emits the first element, then ignores subsequent elements
    /// until the duration has passed.
    ///
    /// ## Usage
    /// ```swift
    /// let throttled = mouseMoves.throttle(.milliseconds(16))
    /// // At most 60fps
    /// ```
    ///
    /// - Parameter duration: The minimum time between emissions.
    /// - Returns: A throttled stream.
    public func throttle(_ duration: Duration) -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Throttle.State(stream: self, duration: duration)
            return Iterator {
                await state.next()
            }
        }
    }
}
