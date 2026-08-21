import Async
import Testing

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(WinSDK)
    import WinSDK
#endif

@Suite
struct Test {

    @Test
    func `chained operators return concrete types`() async {
        let source = Produce([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])

        let pipeline =
            source
            .filter { $0 % 2 == 0 }
            .map { $0 * 3 }
            .compactMap { $0 > 10 ? $0 : nil }

        #expect(
            pipeline is Async.CompactMap<Async.Map<Async.Filter<Produce<Int>>, Int>, Int>
        )

        var results: [Int] = []
        for await value in pipeline {
            results.append(value)
        }

        #expect(results == [12, 18, 24, 30])
    }

    @Test
    func `map into flatMap chains correctly`() async {
        let source = Produce([1, 2, 3])

        let pipeline =
            source
            .map { $0 * 2 }
            .flatMap { Produce([$0, $0 + 1]) }

        #expect(
            pipeline is Async.FlatMap<Async.Map<Produce<Int>, Int>, Produce<Int>>
        )

        var results: [Int] = []
        for await value in pipeline {
            results.append(value)
        }

        #expect(results == [2, 3, 4, 5, 6, 7])
    }

    @Test
    func `map with async closure`() async {
        let source = Produce([1, 2, 3])

        let mapped: Async.Map<Produce<Int>, String> = source.map { value -> String in
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

        let filtered: Async.Filter<Produce<Int>> = source.filter { value -> Bool in
            try? await Task.sleep(for: .microseconds(1))
            return value > 3
        }

        var results: [Int] = []
        for await value in filtered {
            results.append(value)
        }

        #expect(results == [4, 5])
    }

    @Test
    func `sendable source can be erased to Async.Stream and transformed`() async {

        let source = Produce([1, 2, 3, 4, 5])

        let stream =
            Async.Stream(source)
            .filter { $0 % 2 != 0 }
            .map { $0 * 10 }

        var results: [Int] = []
        for await value in stream {
            results.append(value)
        }

        #expect(results == [10, 30, 50])
    }

    @Test @MainActor
    func `sync closure in map runs on caller actor`() async {
        let mainThreadID = currentThreadID()
        let source = Produce([1, 2, 3])
        nonisolated(unsafe) var allOnMain = true

        let mapped = source.map { value -> Int in
            if currentThreadID() != mainThreadID { allOnMain = false }
            return value * 2
        }

        var results: [Int] = []
        for await value in mapped {
            results.append(value)
        }

        #expect(results == [2, 4, 6])
        #expect(allOnMain, "sync map closure should run on MainActor")
    }

    @Test @MainActor
    func `sync closure in filter runs on caller actor`() async {
        let mainThreadID = currentThreadID()
        let source = Produce([1, 2, 3, 4, 5])
        nonisolated(unsafe) var allOnMain = true

        let filtered = source.filter { value -> Bool in
            if currentThreadID() != mainThreadID { allOnMain = false }
            return value > 3
        }

        var results: [Int] = []
        for await value in filtered {
            results.append(value)
        }

        #expect(results == [4, 5])
        #expect(allOnMain, "sync filter closure should run on MainActor")
    }

    @Test @MainActor
    func `sync closure in compactMap runs on caller actor`() async {
        let mainThreadID = currentThreadID()
        let source = Produce(["1", "two", "3", "four", "5"])
        nonisolated(unsafe) var allOnMain = true

        let compacted = source.compactMap { value -> Int? in
            if currentThreadID() != mainThreadID { allOnMain = false }
            return Int(value)
        }

        var results: [Int] = []
        for await value in compacted {
            results.append(value)
        }

        #expect(results == [1, 3, 5])
        #expect(allOnMain, "sync compactMap closure should run on MainActor")
    }

    @Test @MainActor
    func `sync closure in flatMap runs on caller actor`() async {
        let mainThreadID = currentThreadID()
        let source = Produce([1, 2, 3])
        nonisolated(unsafe) var allOnMain = true

        let flat = source.flatMap { value -> Produce<Int> in
            if currentThreadID() != mainThreadID { allOnMain = false }
            return Produce([value, value * 10])
        }

        var results: [Int] = []
        for await value in flat {
            results.append(value)
        }

        #expect(results == [1, 10, 2, 20, 3, 30])
        #expect(allOnMain, "sync flatMap closure should run on MainActor")
    }

    @Test @MainActor
    func `chained sync closures preserve isolation through pipeline`() async {
        let mainThreadID = currentThreadID()
        let source = Produce([1, 2, 3, 4, 5])
        nonisolated(unsafe) var mapOnMain = true
        nonisolated(unsafe) var filterOnMain = true

        let pipeline =
            source
            .map { value -> Int in
                if currentThreadID() != mainThreadID { mapOnMain = false }
                return value * 2
            }
            .filter { value -> Bool in
                if currentThreadID() != mainThreadID { filterOnMain = false }
                return value > 4
            }

        var results: [Int] = []
        for await value in pipeline {
            results.append(value)
        }

        #expect(results == [6, 8, 10])
        #expect(mapOnMain, "sync map closure should run on MainActor")
        #expect(filterOnMain, "sync filter closure should run on MainActor")
    }

    @Test @MainActor
    func `full pipeline preserves isolation through all four operators`() async {
        let mainThreadID = currentThreadID()
        let source = Produce([1, 2, 3, 4, 5, 6])
        nonisolated(unsafe) var filterOnMain = true
        nonisolated(unsafe) var mapOnMain = true
        nonisolated(unsafe) var compactMapOnMain = true
        nonisolated(unsafe) var flatMapOnMain = true

        let pipeline =
            source
            .filter { value -> Bool in
                if currentThreadID() != mainThreadID { filterOnMain = false }
                return value % 2 == 0
            }
            .map { value -> Int in
                if currentThreadID() != mainThreadID { mapOnMain = false }
                return value * 10
            }
            .compactMap { value -> Int? in
                if currentThreadID() != mainThreadID { compactMapOnMain = false }
                return value > 20 ? value : nil
            }
            .flatMap { value -> Produce<Int> in
                if currentThreadID() != mainThreadID { flatMapOnMain = false }
                return Produce([value, value + 1])
            }

        var results: [Int] = []
        for await value in pipeline {
            results.append(value)
        }

        #expect(results == [40, 41, 60, 61])
        #expect(filterOnMain, "filter closure should run on MainActor")
        #expect(mapOnMain, "map closure should run on MainActor")
        #expect(compactMapOnMain, "compactMap closure should run on MainActor")
        #expect(flatMapOnMain, "flatMap closure should run on MainActor")
    }

    @Test @MainActor
    func `stdlib AsyncMapSequence does not preserve caller isolation`() async {
        let mainThreadID = currentThreadID()
        let source = Produce([1, 2, 3])
        nonisolated(unsafe) var allOnMain = true

        let mapped: AsyncMapSequence<Produce<Int>, Int> = source.map { value -> Int in
            if currentThreadID() != mainThreadID { allOnMain = false }
            return value * 2
        }

        var results: [Int] = []
        for await value in mapped {
            results.append(value)
        }

        #expect(results == [2, 4, 6])
        #expect(
            !allOnMain,
            "stdlib map closure should NOT run on MainActor — this is the bug we fix"
        )
    }
}

private func currentThreadID() -> UInt {
    #if canImport(Darwin)
        UInt(pthread_mach_thread_np(pthread_self()))
    #elseif os(Windows)

        UInt(GetCurrentThreadId())
    #else
        UInt(pthread_self())
    #endif
}
