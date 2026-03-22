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

extension Async.Stream.Buffer.Window {
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
        var queue: Queue<Element> = .init()

        @usableFromInline
        var elementCount: Int = 0

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

extension Async.Stream.Buffer.Window.State {
    @usableFromInline
    func next() async -> [Element]? {
        @Dependency(\.clock) var clock
        let resolvedClock = clock
        if upstreamDone && queue.isEmpty {
            return nil
        }

        let deadline = resolvedClock.now.advanced(by: duration)

        while true {
            // Check count first
            if elementCount >= count {
                var result: [Element] = []
                for _ in 0..<count {
                    guard let element = queue.dequeue() else { break }
                    result.append(element)
                }
                elementCount -= result.count
                return result
            }

            if upstreamDone {
                if !queue.isEmpty {
                    var result: [Element] = []
                    queue.drain { result.append($0) }
                    elementCount = 0
                    return result
                }
                return nil
            }

            let now = resolvedClock.now
            let remaining = now.duration(to: deadline)
            if remaining <= .zero {
                // Time window expired
                var result: [Element] = []
                queue.drain { result.append($0) }
                elementCount = 0
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
                queue.enqueue(element)
                elementCount += 1

            case .timerExpired:
                if !queue.isEmpty {
                    var result: [Element] = []
                    queue.drain { result.append($0) }
                    elementCount = 0
                    return result
                }
                // Empty buffer, start new window

            case .upstreamComplete:
                upstreamDone = true
            }
        }
    }
}
