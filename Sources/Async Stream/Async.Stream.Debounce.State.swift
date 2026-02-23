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
                        try? await Task.sleep(for: self.duration)
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

// MARK: - Debounce Method

extension Async.Stream {
    /// Emits only after a quiet period with no new elements.
    ///
    /// When an element arrives, starts a timer. If another element arrives
    /// before the timer expires, restarts the timer. Only emits when the
    /// timer expires without interruption.
    ///
    /// ## Usage
    /// ```swift
    /// let debounced = searchText.debounce(.milliseconds(300))
    /// // Only emits after 300ms of no typing
    /// ```
    ///
    /// - Parameter duration: The quiet period to wait.
    /// - Returns: A debounced stream.
    public func debounce(_ duration: Duration) -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Debounce.State(stream: self, duration: duration)
            return Iterator {
                await state.next()
            }
        }
    }
}
