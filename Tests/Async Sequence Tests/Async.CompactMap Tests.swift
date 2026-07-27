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

@Suite
struct `Async.CompactMap Tests` {

    @Test
    func `transforms and discards nil`() async {
        let source = Produce(["1", "two", "3", "four", "5"])

        let compacted = source.compactMap { Int($0) }

        var results: [Int] = []
        for await value in compacted {
            results.append(value)
        }

        #expect(results == [1, 3, 5])
    }

    @Test
    func `all nil produces empty output`() async {
        let source = Produce(["a", "b", "c"])

        let compacted = source.compactMap { Int($0) }

        var count = 0
        for await _ in compacted {
            count += 1
        }

        #expect(count == 0)
    }

    @Test
    func `no nil keeps all elements`() async {
        let source = Produce([1, 2, 3])

        let compacted = source.compactMap { Optional($0 * 10) }

        var results: [Int] = []
        for await value in compacted {
            results.append(value)
        }

        #expect(results == [10, 20, 30])
    }

    @Test
    func `empty source produces empty output`() async {
        let source = Produce<String>([])

        let compacted = source.compactMap { Int($0) }

        var count = 0
        for await _ in compacted {
            count += 1
        }

        #expect(count == 0)
    }

    @Test
    func `chains with map`() async {
        let source = Produce(["1", "two", "3"])

        let pipeline =
            source
            .compactMap { Int($0) }
            .map { $0 * 100 }

        var results: [Int] = []
        for await value in pipeline {
            results.append(value)
        }

        #expect(results == [100, 300])
    }

    // MARK: - Type Identity

    @Test
    func `sync closure returns concrete Async.CompactMap type`() async {
        let source = Produce(["1", "two", "3"])
        let compacted = source.compactMap { Int($0) }

        #expect(compacted is Async.CompactMap<Produce<String>, Int>)
    }

}
