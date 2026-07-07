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
import Testing

// TEST-004: Async.Stream<Element> is generic — parallel namespace pattern
@Suite("Async.Stream")
struct AsyncStreamTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
}

// MARK: - Unit Tests

extension AsyncStreamTests.Unit {

    // MARK: Construction

    @Test
    func `from creates stream from sequence`() async {
        let stream = Async.Stream.from([1, 2, 3])
        var results: [Int] = []

        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }

    @Test
    func `just emits single value`() async {
        let stream = Async.Stream.just(42)
        var results: [Int] = []

        for await value in stream {
            results.append(value)
        }

        #expect(results == [42])
    }

    @Test
    func `empty completes immediately`() async {
        let stream = Async.Stream<Int>.empty
        var count = 0

        for await _ in stream {
            count += 1
        }

        #expect(count == 0)
    }

    @Test
    func `unfold generates from state`() async {
        let fib = Async.Stream.unfold((0, 1)) { state -> (Int, (Int, Int))? in
            let value = state.0
            if value > 5 { return nil }
            return (value, (state.1, state.0 + state.1))
        }

        var results: [Int] = []
        for await value in fib {
            results.append(value)
        }

        #expect(results == [0, 1, 1, 2, 3, 5])
    }

    // MARK: Transformation

    @Test
    func `map transforms elements`() async {
        let stream = Async.Stream.from([1, 2, 3])
            .map { $0 * 2 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [2, 4, 6])
    }

    @Test
    func `filter removes elements`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5])
            .filter { $0 % 2 == 0 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [2, 4])
    }

    @Test
    func `compactMap transforms and filters`() async {
        let stream = Async.Stream.from(["1", "two", "3"])
            .map.compact { Int($0) }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 3])
    }

    @Test
    func `flatMap concatenates inner streams`() async {
        let stream = Async.Stream.from([1, 2, 3])
            .map.flat { n in
                Async.Stream.from([n, n * 10])
            }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 10, 2, 20, 3, 30])
    }

    // MARK: Accumulation

    @Test
    func `scan accumulates values`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5])
            .scan(0) { $0 + $1 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 3, 6, 10, 15])
    }

    @Test
    func `reduce to single value`() async {
        let sum = await Async.Stream.from([1, 2, 3, 4, 5])
            .reduce(0) { $0 + $1 }

        #expect(sum == 15)
    }

    // MARK: Combination

    @Test
    func `concat joins streams`() async {
        let a = Async.Stream.from([1, 2])
        let b = Async.Stream.from([3, 4])
        let stream = Async.Stream.concat(a, b)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3, 4])
    }

    @Test
    func `zip pairs elements`() async {
        let a = Async.Stream.from([1, 2, 3])
        let b = Async.Stream.from(["a", "b", "c"])
        let stream = a.zip(b)

        var results: [(Int, String)] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results.count == 3)
        #expect(results[0].0 == 1 && results[0].1 == "a")
        #expect(results[1].0 == 2 && results[1].1 == "b")
        #expect(results[2].0 == 3 && results[2].1 == "c")
    }

    // MARK: Prefix

    @Test
    func `prefix takes first N elements`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).prefix(3)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }

    @Test
    func `prefix while takes until predicate fails`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).prefix.while { $0 < 4 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }

    // MARK: Drop

    @Test
    func `drop skips first N elements`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).drop(2)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [3, 4, 5])
    }

    @Test
    func `drop while skips until predicate fails`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).drop.while { $0 < 3 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [3, 4, 5])
    }

    // MARK: Selection

    @Test
    func `first returns only first element`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).first()

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1])
    }

    @Test
    func `last returns only last element`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).last()

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [5])
    }

    // MARK: Deduplication

    @Test
    func `distinctUntilChanged removes consecutive duplicates`() async {
        let stream = Async.Stream.from([1, 1, 2, 2, 2, 3, 1, 1]).distinct.untilChanged()

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3, 1])
    }

    @Test
    func `distinctUntilChanged by key`() async {
        let stream = Async.Stream.from([1, -1, 2, -2, 3])
            .distinct.untilChanged(by: { abs($0) })

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }
}
