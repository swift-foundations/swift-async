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

import Testing
import Async

@Suite("Async.Stream")
struct StreamTests {

    @Test("from sequence")
    func fromSequence() async {
        let stream = Async.Stream.from([1, 2, 3])
        var results: [Int] = []

        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }

    @Test("just emits single value")
    func just() async {
        let stream = Async.Stream.just(42)
        var results: [Int] = []

        for await value in stream {
            results.append(value)
        }

        #expect(results == [42])
    }

    @Test("empty completes immediately")
    func empty() async {
        let stream = Async.Stream<Int>.empty
        var count = 0

        for await _ in stream {
            count += 1
        }

        #expect(count == 0)
    }

    @Test("map transforms elements")
    func map() async {
        let stream = Async.Stream.from([1, 2, 3])
            .map { $0 * 2 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [2, 4, 6])
    }

    @Test("filter removes elements")
    func filter() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5])
            .filter { $0 % 2 == 0 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [2, 4])
    }

    @Test("compactMap transforms and filters")
    func compactMap() async {
        let stream = Async.Stream.from(["1", "two", "3"])
            .compactMap { Int($0) }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 3])
    }

    @Test("scan accumulates")
    func scan() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5])
            .scan(0) { $0 + $1 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 3, 6, 10, 15])
    }

    @Test("reduce to single value")
    func reduce() async {
        let sum = await Async.Stream.from([1, 2, 3, 4, 5])
            .reduce(0) { $0 + $1 }

        #expect(sum == 15)
    }

    @Test("concat joins streams")
    func concat() async {
        let a = Async.Stream.from([1, 2])
        let b = Async.Stream.from([3, 4])
        let stream = Async.Stream.concat(a, b)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3, 4])
    }

    @Test("zip pairs elements")
    func zip() async {
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

    @Test("flatMap concatenates inner streams")
    func flatMap() async {
        let stream = Async.Stream.from([1, 2, 3])
            .flatMap { n in
                Async.Stream.from([n, n * 10])
            }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 10, 2, 20, 3, 30])
    }

    // MARK: - Unfold

    @Test("unfold generates from state")
    func unfold() async {
        // Fibonacci: generate first 6 numbers
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

    // MARK: - Prefix

    @Test("prefix takes first N elements")
    func prefixCount() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).prefix(3)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }

    @Test("prefix while takes until predicate fails")
    func prefixWhile() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).prefix.while { $0 < 4 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }

    // MARK: - Drop

    @Test("drop skips first N elements")
    func dropCount() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).drop(2)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [3, 4, 5])
    }

    @Test("drop while skips until predicate fails")
    func dropWhile() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).drop.while { $0 < 3 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [3, 4, 5])
    }

    // MARK: - First/Last

    @Test("first returns only first element")
    func firstElement() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).first()

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1])
    }

    @Test("last returns only last element")
    func lastElement() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5]).last()

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [5])
    }

    // MARK: - DistinctUntilChanged

    @Test("distinctUntilChanged removes consecutive duplicates")
    func distinctUntilChanged() async {
        let stream = Async.Stream.from([1, 1, 2, 2, 2, 3, 1, 1]).distinctUntilChanged()

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3, 1])
    }

    @Test("distinctUntilChanged by key")
    func distinctUntilChangedByKey() async {
        let stream = Async.Stream.from([1, -1, 2, -2, 3])
            .distinctUntilChanged { abs($0) }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }
}
