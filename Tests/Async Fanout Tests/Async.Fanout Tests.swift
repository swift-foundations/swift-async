import Async
import Synchronization
import Testing

@Suite
struct `Async.Fanout Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Async.Fanout Tests`.Unit {

    @Test
    func `results come back in input order however the work completes`() async {
        let items = Array(0..<24)

        let results = await Async.Fanout(jobs: 24).mapAsync(items) { item in

            try? await Task.sleep(for: .milliseconds(5 * (24 - item)))
            return item
        }

        #expect(results == items)
    }

    @Test
    func `every item is measured, and none twice, when the bound is below the population`() async {
        let items = Array(0..<200)

        let results = await Async.Fanout(jobs: 4).map(items) { $0 * 2 }

        #expect(results == items.map { $0 * 2 })
    }

    @Test
    func `completion is reported once per item, counting up to the population`() async {
        let counts = Counts()

        _ = await Async.Fanout(jobs: 6).map(
            Array(0..<50),
            completed: { counts.record($0) },
            { $0 }
        )

        #expect(counts.observed == Array(1...50))
    }
}

extension `Async.Fanout Tests`.`Edge Case` {

    @Test
    func `an empty population runs nothing and reports nothing`() async {
        let counts = Counts()

        let results = await Async.Fanout(jobs: 4).map(
            [Swift.Int](),
            completed: { counts.record($0) },
            { $0 }
        )

        #expect(results.isEmpty)
        #expect(counts.observed.isEmpty)
    }

    @Test
    func `the bound is at least one, whatever it is asked for`() {
        #expect(Async.Fanout(jobs: 0).jobs == 1)
        #expect(Async.Fanout(jobs: -8).jobs == 1)
        #expect(Async.Fanout(jobs: 3).jobs == 3)
    }
}

private final class Counts: Sendable {
    private let storage = Mutex([Swift.Int]())
}

extension Counts {
    func record(_ count: Swift.Int) {
        storage.withLock { $0.append(count) }
    }

    var observed: [Swift.Int] {
        storage.withLock { $0 }
    }
}
