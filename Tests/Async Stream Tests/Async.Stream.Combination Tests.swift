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

// MARK: - Combination Operator Unit Tests

extension AsyncStreamTests.Unit {

    // MARK: Merge

    @Test
    func `merge combines elements from two streams`() async {
        let a = Async.Stream.from([1, 3, 5])
        let b = Async.Stream.from([2, 4, 6])
        let stream = Async.Stream.merge(a, b)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        // Merge doesn't guarantee order, just that all elements appear
        #expect(results.sorted() == [1, 2, 3, 4, 5, 6])
    }

    @Test
    func `merge three streams`() async {
        let a = Async.Stream.from([1])
        let b = Async.Stream.from([2])
        let c = Async.Stream.from([3])
        let stream = Async.Stream.merge(a, b, c)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results.sorted() == [1, 2, 3])
    }

    @Test
    func `merge array of streams`() async {
        let streams = [
            Async.Stream.from([1, 2]),
            Async.Stream.from([3, 4]),
            Async.Stream.from([5, 6]),
        ]
        let stream = Async.Stream.merge(streams)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results.sorted() == [1, 2, 3, 4, 5, 6])
    }

    @Test
    func `merge empty array returns empty stream`() async {
        let stream = Async.Stream<Int>.merge([])
        var count = 0
        for await _ in stream {
            count += 1
        }
        #expect(count == 0)
    }

    @Test
    func `merge with one empty stream`() async {
        let a = Async.Stream.from([1, 2, 3])
        let b = Async.Stream<Int>.empty
        let stream = Async.Stream.merge(a, b)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results.sorted() == [1, 2, 3])
    }

    // MARK: Concat (additional variants)

    @Test
    func `concat three streams`() async {
        let a = Async.Stream.from([1])
        let b = Async.Stream.from([2])
        let c = Async.Stream.from([3])
        let stream = Async.Stream.concat(a, b, c)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }

    @Test
    func `concat array of streams preserves order`() async {
        let streams = [
            Async.Stream.from([1, 2]),
            Async.Stream.from([3, 4]),
            Async.Stream.from([5, 6]),
        ]
        let stream = Async.Stream.concat(streams)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3, 4, 5, 6])
    }

    // MARK: Zip (transform variant)

    @Test
    func `zip with transform combines elements`() async {
        let a = Async.Stream.from([1, 2, 3])
        let b = Async.Stream.from([10, 20, 30])
        let stream = a.zip(b) { $0 + $1 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [11, 22, 33])
    }

    @Test
    func `zip stops at shorter stream`() async {
        let a = Async.Stream.from([1, 2, 3, 4, 5])
        let b = Async.Stream.from(["a", "b"])
        let stream = a.zip(b)

        var results: [(Int, String)] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results.count == 2)
        #expect(results[0].0 == 1 && results[0].1 == "a")
        #expect(results[1].0 == 2 && results[1].1 == "b")
    }

    // MARK: FlatMapLatest

    @Test
    func `flatMapLatest switches to latest inner stream`() async {
        // Each outer element produces a stream of [n, n*10]
        // Since outer elements arrive instantly, each new one cancels the previous
        // The last outer element (3) should produce its full inner stream
        let stream = Async.Stream.from([1, 2, 3])
            .map.flat.latest { n in
                Async.Stream.from([n, n * 10])
            }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        // At minimum, the last inner stream [3, 30] should complete
        #expect(results.contains(3))
        #expect(results.contains(30))
    }

    @Test
    func `flatMapLatest with single element`() async {
        let stream = Async.Stream.from([42])
            .map.flat.latest { n in
                Async.Stream.from([n, n * 2])
            }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [42, 84])
    }
}
