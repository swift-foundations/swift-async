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
internal import Clocks_Dependencies
public import Ownership_Primitives

extension Async.Stream.Debounce {
    /// Internal state for debounce.
    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let duration: Duration

        @usableFromInline
        var pending: Element?

        @usableFromInline
        var upstreamDone: Bool = false

        @usableFromInline
        init(stream: Async.Stream<Element>, duration: Duration) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.duration = duration
        }
    }
}

extension Async.Stream.Debounce.State {
    @usableFromInline
    func next() async -> Element? {
        @Dependency(\.clock) var clock
        let resolvedClock = clock
        if upstreamDone {
            // Emit any pending element
            if let element = pending {
                pending = nil
                return element
            }
            return nil
        }

        while true {
            // Race: get next element vs timer expiry
            let result = await withTaskGroup(of: Async.Stream<Element>.Debounce.Event.self) { group in
                group.addTask {
                    if let element = await self.box.next() {
                        return .element(element)
                    } else {
                        return .upstreamComplete
                    }
                }

                if self.pending != nil {
                    group.addTask {
                        try? await resolvedClock.sleep(until: resolvedClock.now.advanced(by: self.duration))
                        return .timerExpired
                    }
                }

                // Wait for first result
                guard let first = await group.next() else {
                    return Async.Stream<Element>.Debounce.Event.upstreamComplete
                }
                group.cancelAll()
                return first
            }

            switch result {
            case .element(let element):
                // New element arrived, update pending and restart timer
                pending = element
                continue

            case .timerExpired:
                // Quiet period elapsed, emit pending
                if let element = pending {
                    pending = nil
                    return element
                }
                continue

            case .upstreamComplete:
                upstreamDone = true
                // Emit any pending element
                if let element = pending {
                    pending = nil
                    return element
                }
                return nil
            }
        }
    }
}
