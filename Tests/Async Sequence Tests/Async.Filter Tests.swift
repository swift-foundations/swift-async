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

@Suite("Async.Filter")
struct AsyncFilterTests {

    @Test
    func `includes matching elements`() async {
        let source = Produce([1, 2, 3, 4, 5])

        let filtered = source.filter { $0 > 3 }

        var results: [Int] = []
        for await value in filtered {
            results.append(value)
        }

        #expect(results == [4, 5])
    }

    @Test
    func `excludes all when none match`() async {
        let source = Produce([1, 2, 3])

        let filtered = source.filter { $0 > 100 }

        var count = 0
        for await _ in filtered {
            count += 1
        }

        #expect(count == 0)
    }

    @Test
    func `includes all when all match`() async {
        let source = Produce([1, 2, 3])

        let filtered = source.filter { _ in true }

        var results: [Int] = []
        for await value in filtered {
            results.append(value)
        }

        #expect(results == [1, 2, 3])
    }

    @Test
    func `empty source produces empty output`() async {
        let source = Produce<Int>([])

        let filtered = source.filter { _ in true }

        var count = 0
        for await _ in filtered {
            count += 1
        }

        #expect(count == 0)
    }

    @Test
    func `preserves element order`() async {
        let source = Produce([5, 3, 1, 4, 2])

        let filtered = source.filter { $0 % 2 != 0 }

        var results: [Int] = []
        for await value in filtered {
            results.append(value)
        }

        #expect(results == [5, 3, 1])
    }

    // MARK: - Type Identity

    @Test
    func `sync closure returns concrete Async.Filter type`() async {
        let source = Produce([1, 2, 3])
        let filtered = source.filter { $0 > 1 }

        #expect(filtered is Async.Filter<Produce<Int>>)
    }

}
