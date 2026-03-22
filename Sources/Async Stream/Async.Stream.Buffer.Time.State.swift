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
public import Ownership_Primitives
public import Clocks
internal import Clocks_Dependency

extension Async.Stream.Buffer.Time {
    /// Internal state for time-based buffering.
    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let duration: Duration

        @usableFromInline
        var buffer: [Element] = []

        @usableFromInline
        var upstreamDone: Bool = false

        @usableFromInline
        init(stream: Async.Stream<Element>, duration: Duration) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.duration = duration
        }
    }
}

extension Async.Stream.Buffer.Time.State {
    @usableFromInline
    func next() async -> [Element]? {
        @Dependency(\.clock) var clock
        let resolvedClock = clock
        if upstreamDone {
            return nil
        }

        let deadline = resolvedClock.now.advanced(by: duration)

        while true {
            let now = resolvedClock.now
            let remaining = now.duration(to: deadline)
            if remaining <= .zero {
                // Time window expired
                let result = buffer
                buffer = []
                if result.isEmpty && upstreamDone {
                    return nil
                }
                return result
            }

            // Race: get next element vs timer
            let result = await withTaskGroup(of: Async.Stream<Element>.Buffer.Time.Event.self) { group in
                group.addTask {
                    if let element = await self.box.next() {
                        return .element(element)
                    } else {
                        return .upstreamComplete
                    }
                }

                group.addTask {
                    try? await resolvedClock.sleep(until: resolvedClock.now.advanced(by: remaining))
                    return .timerExpired
                }

                guard let first = await group.next() else {
                    return Async.Stream<Element>.Buffer.Time.Event.upstreamComplete
                }
                group.cancelAll()
                return first
            }

            switch result {
            case .element(let element):
                buffer.append(element)

            case .timerExpired:
                let result = buffer
                buffer = []
                return result

            case .upstreamComplete:
                upstreamDone = true
                if !buffer.isEmpty {
                    let result = buffer
                    buffer = []
                    return result
                }
                return nil
            }
        }
    }
}
