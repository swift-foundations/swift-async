extension Async.Fanout {

    public func map<Item: Sendable, Result: Sendable>(
        _ items: [Item],
        completed: @escaping @Sendable (Swift.Int) -> Void = { _ in },
        _ work: @escaping @Sendable (Item) -> Result
    ) async -> [Result] {
        guard !items.isEmpty else { return [] }
        return await withTaskGroup(of: (offset: Swift.Int, value: Result).self) { group in
            var next = 0
            var finished = 0
            var results = [Result?](repeating: nil, count: items.count)

            while next < items.count, next < jobs {
                let offset = next
                let item = items[offset]
                group.addTask { (offset: offset, value: work(item)) }
                next += 1
            }
            while let outcome = await group.next() {
                results[outcome.offset] = outcome.value
                finished += 1
                completed(finished)
                guard next < items.count else { continue }
                let offset = next
                let item = items[offset]
                group.addTask { (offset: offset, value: work(item)) }
                next += 1
            }
            return results.compactMap { $0 }
        }
    }
}
