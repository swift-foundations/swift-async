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
public import Reference_Primitives

extension Async.Stream.Buffer {
    /// Namespace for count-or-time buffering.
    public enum CountOrTime {}
}

extension Async.Stream.Buffer.CountOrTime {
    /// Internal state for count-or-time buffering.
    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let count: Int

        @usableFromInline
        let duration: Duration

        @usableFromInline
        var buffer: [Element] = []

        @usableFromInline
        var upstreamDone: Bool = false

        @usableFromInline
        init(stream: Async.Stream<Element>, count: Int, duration: Duration) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.count = max(1, count)
            self.duration = duration
        }
    }
}

extension Async.Stream.Buffer.CountOrTime.State {
    @usableFromInline
    func next() async -> [Element]? {
        if upstreamDone && buffer.isEmpty {
            return nil
        }

        let deadline = ContinuousClock.now + duration

        while true {
            // Check count first
            if buffer.count >= count {
                let result = Array(buffer.prefix(count))
                buffer.removeFirst(min(count, buffer.count))
                return result
            }

            if upstreamDone {
                if !buffer.isEmpty {
                    let result = buffer
                    buffer = []
                    return result
                }
                return nil
            }

            let remaining = deadline - ContinuousClock.now
            if remaining <= .zero {
                // Time window expired
                let result = buffer
                buffer = []
                if result.isEmpty {
                    continue // Start new window
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
                    try? await Task.sleep(for: remaining)
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
                if !buffer.isEmpty {
                    let result = buffer
                    buffer = []
                    return result
                }
                // Empty buffer, start new window

            case .upstreamComplete:
                upstreamDone = true
            }
        }
    }
}
