struct Produce<Element: Sendable>: AsyncSequence, Sendable {
    let values: [Element]

    init(_ values: [Element]) {
        self.values = values
    }

    struct Iterator: AsyncIteratorProtocol {
        var index: Int = 0
        let values: [Element]

        mutating func next(
            isolation actor: isolated (any Actor)? = #isolation
        ) async -> Element? {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(values: values)
    }
}
