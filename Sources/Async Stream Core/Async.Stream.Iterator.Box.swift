public import Async_Primitives
public import Ownership_Primitives

extension Async.Stream.Iterator {

    public typealias Box<I: AsyncIteratorProtocol> = Ownership.Mutable<I>.Unchecked
}
