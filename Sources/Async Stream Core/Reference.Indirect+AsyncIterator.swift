public import Ownership_Primitives

extension Ownership.Mutable.Unchecked where Value: AsyncIteratorProtocol {

    public func next() async -> Value.Element? {

        try? await mutable.value.next()
    }
}
