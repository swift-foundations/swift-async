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

// MARK: - Remaining Operator Unit Tests

private actor Counter {
    var value = 0
}

extension Counter {
    func next() -> Int? {
        value += 1
        return value <= 5 ? value : nil
    }
}

extension AsyncStreamTests.Unit {

    // MARK: Generate

    @Test
    func `generate creates stream from generator function`() async {
        let counter = Counter()
        let stream = Async.Stream<Int>.generate {
            await counter.next()
        }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3, 4, 5])
    }

    // MARK: Never

    @Test
    func `never does not emit when cancelled`() async {
        let stream = Async.Stream<Int>.never
        let task = Task {
            var count = 0
            for await _ in stream { count += 1 }
            return count
        }
        task.cancel()
        let count = await task.value
        #expect(count == 0)
    }

    // MARK: Async Map

    @Test
    func `async map transforms elements`() async {
        let stream = Async.Stream.from([1, 2, 3])
            .map { value async -> String in
                "\(value)"
            }

        var results: [String] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == ["1", "2", "3"])
    }

    // MARK: Async Filter

    @Test
    func `async filter removes elements`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5])
            .filter { value async -> Bool in
                value % 2 == 0
            }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [2, 4])
    }

    // MARK: Async CompactMap

    @Test
    func `async compactMap transforms and filters`() async {
        let stream = Async.Stream.from(["1", "two", "3"])
            .map.compact { value async -> Int? in
                Int(value)
            }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 3])
    }

    // MARK: First (with predicate)

    @Test
    func `first where returns first matching element`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5])
            .first { $0 > 3 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [4])
    }

    @Test
    func `first where with no match returns empty`() async {
        let stream = Async.Stream.from([1, 2, 3])
            .first { $0 > 10 }

        var count = 0
        for await _ in stream {
            count += 1
        }

        #expect(count == 0)
    }

    // MARK: Last (with predicate)

    @Test
    func `last where returns last matching element`() async {
        let stream = Async.Stream.from([1, 2, 3, 4, 5])
            .last { $0 < 4 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [3])
    }

    @Test
    func `last where with no match returns empty`() async {
        let stream = Async.Stream.from([1, 2, 3])
            .last { $0 > 10 }

        var count = 0
        for await _ in stream {
            count += 1
        }

        #expect(count == 0)
    }

    // MARK: DistinctUntilChanged (custom equality)

    @Test
    func `distinctUntilChanged with custom equality`() async {
        let stream = Async.Stream.from([1, -1, 2, -2, 3])
            .distinct.untilChanged { abs($0) == abs($1) }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }
}
