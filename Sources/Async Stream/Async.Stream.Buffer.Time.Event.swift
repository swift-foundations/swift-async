public import Async_Primitives

extension Async.Stream.Buffer.Time {
    @usableFromInline
    enum Event: Sendable {
        case element(Element)
        case timerExpired
        case upstreamComplete
    }
}
