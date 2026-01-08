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

public import StandardsCollections

// MARK: - Receive Accessor

extension Async.Channel.Bounded {
    /// Accessor for receive operations.
    @inlinable
    public var receive: Receive {
        Receive(channel: self)
    }
}

// MARK: - Receive Type

extension Async.Channel.Bounded {
    /// Namespace for receive operations.
    public struct Receive: Sendable {
        @usableFromInline
        let channel: Async.Channel.Bounded<Element>

        @usableFromInline
        init(channel: Async.Channel.Bounded<Element>) {
            self.channel = channel
        }
    }
}

// MARK: - Receive Operations

extension Async.Channel.Bounded.Receive {
    /// Receive the next element from the channel.
    ///
    /// Suspends if the buffer is empty until an element becomes available
    /// or the channel is closed and drained.
    ///
    /// - Important: Only one task may call this method at a time.
    ///   Concurrent calls violate the single-consumer invariant.
    ///
    /// - Returns: The next element, or `nil` if the channel is closed and drained.
    /// - Throws: `Async.Channel.Bounded.Error.cancelled` if the task is cancelled.
    @inlinable
    public func callAsFunction() async throws(Async.Channel.Error) -> Element? {
        // Fast path: try immediate receive
        let fastAction = channel.storage.withLock { state in
            state.tryReceive()
        }

        switch fastAction {
        case .returnElement(let element, let resumeSender, var cancelled):
            // Resume cancelled senders first (minimizes stuck time)
            while let c = cancelled.take.front {
                c.resume(returning: .cancelled)
            }
            resumeSender?.resume(returning: nil)
            return element
        case .returnNil:
            return nil
        case .rejectCancelled:
            throw .cancelled
        case .suspend:
            break // Fall through to slow path
        }

        // Slow path: need to suspend
        let (element, error): (Element?, Async.Channel.Error?) = await withTaskCancellationHandler {
            await withUnsafeContinuation { (continuation: UnsafeContinuation<(Element?, Async.Channel.Error?), Never>) in
                let action = channel.storage.withLock { state in
                    state.receiveSuspended(continuation: continuation)
                }

                switch action {
                case .returnElement(let element, let resumeSender, var cancelled):
                    // Resume cancelled senders first (minimizes stuck time)
                    while let c = cancelled.take.front {
                        c.resume(returning: .cancelled)
                    }
                    resumeSender?.resume(returning: nil)
                    continuation.resume(returning: (element, nil))
                case .returnNil:
                    continuation.resume(returning: (nil, nil))
                case .rejectCancelled:
                    continuation.resume(returning: (nil, .cancelled))
                case .suspend:
                    // Continuation stored, will be resumed later
                    break
                }
            }
        } onCancel: {
            let action = channel.storage.withLock { state in
                state.receiveCancelled()
            }
            switch action {
            case .resumeWithCancellation(let continuation):
                continuation.resume(returning: (nil, .cancelled))
            case .none:
                break
            }
        }

        if let error { throw error }
        return element
    }

    /// Try to receive an element without suspending.
    ///
    /// - Returns: The next element if available, `nil` if the buffer is empty.
    @inlinable
    public func tryOne() -> Element? {
        let action = channel.storage.withLock { state in
            state.tryReceive()
        }

        switch action {
        case .returnElement(let element, let resumeSender, var cancelled):
            // Resume cancelled senders first (minimizes stuck time)
            while let c = cancelled.take.front {
                c.resume(returning: .cancelled)
            }
            resumeSender?.resume(returning: nil)
            return element
        case .returnNil, .rejectCancelled, .suspend:
            return nil
        }
    }
}
