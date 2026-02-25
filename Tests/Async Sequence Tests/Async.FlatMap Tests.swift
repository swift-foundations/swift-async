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

@Suite("Async.FlatMap")
struct AsyncFlatMapTests {

    @Test
    func `flattens inner sequences`() async {
        let source = Produce([1, 2, 3])

        let flat = source.flatMap { value in
            Produce([value, value * 10])
        }

        var results: [Int] = []
        for await value in flat {
            results.append(value)
        }

        #expect(results == [1, 10, 2, 20, 3, 30])
    }

    @Test
    func `empty inner sequences produce no elements`() async {
        let source = Produce([1, 2, 3])

        let flat = source.flatMap { _ in
            Produce<Int>([])
        }

        var count = 0
        for await _ in flat {
            count += 1
        }

        #expect(count == 0)
    }

    @Test
    func `empty base produces empty output`() async {
        let source = Produce<Int>([])

        let flat = source.flatMap { value in
            Produce([value])
        }

        var count = 0
        for await _ in flat {
            count += 1
        }

        #expect(count == 0)
    }

    @Test
    func `single element inner sequences act like map`() async {
        let source = Produce([1, 2, 3])

        let flat = source.flatMap { value in
            Produce([value * 5])
        }

        var results: [Int] = []
        for await value in flat {
            results.append(value)
        }

        #expect(results == [5, 10, 15])
    }

    @Test
    func `chains with filter`() async {
        let source = Produce([1, 2, 3])

        let pipeline = source
            .flatMap { Produce([$0, $0 * 10]) }
            .filter { $0 > 5 }

        var results: [Int] = []
        for await value in pipeline {
            results.append(value)
        }

        #expect(results == [10, 20, 30])
    }

    // MARK: - Type Identity

    @Test
    func `sync closure returns concrete Async.FlatMap type`() async {
        let source = Produce([1, 2, 3])
        let flat = source.flatMap { Produce([$0]) }

        #expect(flat is Async.FlatMap<Produce<Int>, Produce<Int>>)
    }

}
