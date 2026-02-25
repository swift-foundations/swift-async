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

@Suite("Async.Map")
struct AsyncMapTests {

    @Test
    func `transforms each element`() async {
        let source = Produce([1, 2, 3])

        let mapped = source.map { $0 * 10 }

        var results: [Int] = []
        for await value in mapped {
            results.append(value)
        }

        #expect(results == [10, 20, 30])
    }

    @Test
    func `transforms element type`() async {
        let source = Produce([1, 2, 3])

        let mapped = source.map { "value: \($0)" }

        var results: [String] = []
        for await value in mapped {
            results.append(value)
        }

        #expect(results == ["value: 1", "value: 2", "value: 3"])
    }

    @Test
    func `empty source produces empty output`() async {
        let source = Produce<Int>([])

        let mapped = source.map { $0 * 2 }

        var count = 0
        for await _ in mapped {
            count += 1
        }

        #expect(count == 0)
    }

    @Test
    func `chains with filter`() async {
        let source = Produce([1, 2, 3, 4, 5])

        let pipeline = source
            .map { $0 * 2 }
            .filter { $0 > 4 }

        var results: [Int] = []
        for await value in pipeline {
            results.append(value)
        }

        #expect(results == [6, 8, 10])
    }

    // MARK: - Type Identity

    @Test
    func `sync closure returns concrete Async.Map type`() async {
        let source = Produce([1, 2, 3])
        let mapped = source.map { $0 * 2 }

        #expect(mapped is Async.Map<Produce<Int>, Int>)
    }

}
