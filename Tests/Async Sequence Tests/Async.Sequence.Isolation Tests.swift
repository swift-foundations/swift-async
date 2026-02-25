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
import Foundation

@Suite("Async.Sequence.Isolation")
struct AsyncSequenceIsolationTests {

    // MARK: - Chaining

    @Test
    func `chained operators produce correct results`() async {
        let source = Produce([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])

        let pipeline = source
            .filter { $0 % 2 == 0 }
            .map { $0 * 3 }
            .compactMap { $0 > 10 ? $0 : nil }

        var results: [Int] = []
        for await value in pipeline {
            results.append(value)
        }

        // Even: 2, 4, 6, 8, 10 → *3: 6, 12, 18, 24, 30 → >10: 12, 18, 24, 30
        #expect(results == [12, 18, 24, 30])
    }

    @Test
    func `map into flatMap chains correctly`() async {
        let source = Produce([1, 2, 3])

        let pipeline = source
            .map { $0 * 2 }
            .flatMap { Produce([$0, $0 + 1]) }

        var results: [Int] = []
        for await value in pipeline {
            results.append(value)
        }

        // 1→2, 2→4, 3→6 then flatMap: [2,3], [4,5], [6,7]
        #expect(results == [2, 3, 4, 5, 6, 7])
    }

    // MARK: - Async Closures

    @Test
    func `map with async closure`() async {
        let source = Produce([1, 2, 3])

        let mapped = source.map { value -> String in
            try? await Task.sleep(for: .microseconds(1))
            return "\(value)"
        }

        var results: [String] = []
        for await value in mapped {
            results.append(value)
        }

        #expect(results == ["1", "2", "3"])
    }

    @Test
    func `filter with async closure`() async {
        let source = Produce([1, 2, 3, 4, 5])

        let filtered = source.filter { value -> Bool in
            try? await Task.sleep(for: .microseconds(1))
            return value > 3
        }

        var results: [Int] = []
        for await value in filtered {
            results.append(value)
        }

        #expect(results == [4, 5])
    }

    // MARK: - Late Erasure to Async.Stream

    @Test
    func `concrete pipeline can be erased to Async.Stream`() async {
        let source = Produce([1, 2, 3, 4, 5])

        let concrete = source
            .filter { $0 % 2 != 0 }
            .map { $0 * 10 }

        // Erase at the boundary
        let stream = Async.Stream(concrete)

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [10, 30, 50])
    }
}
