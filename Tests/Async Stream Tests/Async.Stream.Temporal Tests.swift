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

import Async
import Clocks_Dependencies
import Testing

// MARK: - Temporal Operator Unit Tests

extension `Async.Stream Tests`.Unit {

    // MARK: Delay

    @Test
    func `delay preserves all elements`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream.from([1, 2, 3]).delay(.seconds(1))
            var results: [Int] = []
            for await value in stream {
                results.append(value)
            }
            #expect(results == [1, 2, 3])
        }
    }

    @Test
    func `delay preserves element order`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream.from([5, 4, 3, 2, 1]).delay(.milliseconds(100))
            var results: [Int] = []
            for await value in stream {
                results.append(value)
            }
            #expect(results == [5, 4, 3, 2, 1])
        }
    }

    @Test
    func `delay on empty stream completes immediately`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream<Int>.empty.delay(.seconds(1))
            var count = 0
            for await _ in stream {
                count += 1
            }
            #expect(count == 0)
        }
    }

    // MARK: Interval

    @Test
    func `interval emits sequential integers`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream<Int>.interval(.seconds(1)).prefix(5)
            var results: [Int] = []
            for await value in stream {
                results.append(value)
            }
            #expect(results == [0, 1, 2, 3, 4])
        }
    }

    @Test
    func `interval starts at zero`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream<Int>.interval(.milliseconds(100)).prefix(1)
            var results: [Int] = []
            for await value in stream {
                results.append(value)
            }
            #expect(results == [0])
        }
    }

    // MARK: Timer (Void)

    @Test
    func `timer emits once then completes`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream<Void>.timer(after: .seconds(5))
            var count = 0
            for await _ in stream {
                count += 1
            }
            #expect(count == 1)
        }
    }

    // MARK: Timer (Value)

    @Test
    func `timer with value emits value once`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream<Swift.String>.timer(after: .seconds(1), value: "hello")
            var results: [Swift.String] = []
            for await value in stream {
                results.append(value)
            }
            #expect(results == ["hello"])
        }
    }

    // MARK: Throttle

    @Test
    func `throttle emits first and suppresses rapid followers`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            // With Clock.Immediate, no time passes between elements,
            // so throttle allows only the first element through.
            let stream = Async.Stream.from([1, 2, 3, 4, 5]).throttle(.seconds(1))
            var results: [Int] = []
            for await value in stream {
                results.append(value)
            }
            #expect(results == [1])
        }
    }

    @Test
    func `throttle on single element emits it`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream.from([42]).throttle(.seconds(1))
            var results: [Int] = []
            for await value in stream {
                results.append(value)
            }
            #expect(results == [42])
        }
    }

    @Test
    func `throttle on empty stream completes`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream<Int>.empty.throttle(.seconds(1))
            var count = 0
            for await _ in stream {
                count += 1
            }
            #expect(count == 0)
        }
    }

    // MARK: Repeating (with interval)

    @Test
    func `repeating with interval emits value N times`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream<Swift.String>.repeating("ping", every: .seconds(1), count: 3)
            var results: [Swift.String] = []
            for await value in stream {
                results.append(value)
            }
            #expect(results == ["ping", "ping", "ping"])
        }
    }

    @Test
    func `repeating with interval and zero count emits nothing`() async {
        await withDependencies {
            $0.clock = Clock.`Any`(Clock.Immediate())
        } operation: {
            let stream = Async.Stream<Swift.String>.repeating("ping", every: .seconds(1), count: 0)
            var count = 0
            for await _ in stream {
                count += 1
            }
            #expect(count == 0)
        }
    }

    // MARK: Repeating (no interval)

    @Test
    func `repeating emits value N times`() async {
        let stream = Async.Stream.repeating(42, count: 4)
        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }
        #expect(results == [42, 42, 42, 42])
    }

    @Test
    func `repeating with zero count emits nothing`() async {
        let stream = Async.Stream.repeating(42, count: 0)
        var count = 0
        for await _ in stream {
            count += 1
        }
        #expect(count == 0)
    }
}
