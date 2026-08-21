public import Async_Primitives
internal import Buffer_Primitive
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Ring_Primitive
internal import Buffer_Ring_Primitives
internal import Cardinal_Primitives
public import Column_Primitives
internal import Memory_Allocator_Primitive
internal import Memory_Heap_Primitives
public import Ownership_Primitives
public import Storage_Contiguous_Primitives

extension Async.Stream.Buffer.Count {

    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let count: Index<Element>.Count

        @usableFromInline
        var ring: Column.Ring<Element>.Bounded

        @usableFromInline
        init(stream: Async.Stream<Element>, count: Int) {

            let typedCount = try! Index<Element>.Count(max(1, count))
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.count = typedCount
            self.ring = Column.Ring<Element>.Bounded(minimumCapacity: typedCount)
        }
    }
}

extension Async.Stream.Buffer.Count.State {
    @usableFromInline
    func next() async -> [Element]? {
        while true {
            guard let element = await box.next() else {

                if ring.count > .zero {
                    var result: [Element] = []
                    ring.drain { result.append($0) }
                    return result
                }
                return nil
            }

            ring.push.back(element)

            if ring.count >= count {
                var result: [Element] = []
                ring.drain { result.append($0) }
                return result
            }
        }
    }
}
