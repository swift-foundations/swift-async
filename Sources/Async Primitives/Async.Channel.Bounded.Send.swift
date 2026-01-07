// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-runtime open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-runtime project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Send Accessor

extension Async.Channel.Bounded {
    /// Accessor for send operations.
    @inlinable
    public var send: Send {
        Send(channel: self)
    }
}

// MARK: - Send Type

extension Async.Channel.Bounded {
    /// Namespace for send operations.
    public struct Send: Sendable {
        @usableFromInline
        let channel: Async.Channel.Bounded<Element>

        @usableFromInline
        init(channel: Async.Channel.Bounded<Element>) {
            self.channel = channel
        }
    }
}

// MARK: - Send Operations

extension Async.Channel.Bounded.Send {
    /// Send an element to the channel.
    ///
    /// Suspends if the buffer is full until space becomes available
    /// or the channel is closed.
    ///
    /// - Parameter element: The element to send.
    /// - Throws: `Async.Channel.Error.closed` if the channel is closed.
    ///           `Async.Channel.Error.cancelled` if the task is cancelled.
    @inlinable
    public func callAsFunction(_ element: Element) async throws(Async.Channel.Error) {
        // Fast path: try immediate send
        let fastAction = channel.storage.withLock { state in
            state.trySend(element)
        }

        switch fastAction {
        case .deliverToReceiver(let receiverCont, let element):
            receiverCont.resume(returning: (element, nil))
            return
        case .buffered:
            return
        case .rejectClosed:
            throw .closed
        case .rejectCancelled:
            throw .cancelled
        case .suspend:
            break // Fall through to slow path
        }

        // Slow path: need to suspend
        let id = channel.storage.withLock { state in
            state.generateId()
        }

        let error: Async.Channel.Error? = await withTaskCancellationHandler {
            await withUnsafeContinuation { (continuation: UnsafeContinuation<Async.Channel.Error?, Never>) in
                let action = channel.storage.withLock { state in
                    state.sendSuspended(id: id, element: element, continuation: continuation)
                }

                switch action {
                case .deliverToReceiver(let receiverCont, let element):
                    receiverCont.resume(returning: (element, nil))
                    continuation.resume(returning: nil)
                case .buffered:
                    continuation.resume(returning: nil)
                case .rejectClosed:
                    continuation.resume(returning: .closed)
                case .rejectCancelled:
                    continuation.resume(returning: .cancelled)
                case .suspend:
                    // Continuation stored, will be resumed later
                    break
                }
            }
        } onCancel: {
            let action = channel.storage.withLock { state in
                state.sendCancelled(id: id)
            }
            switch action {
            case .resumeWithCancellation(let continuation):
                continuation.resume(returning: .cancelled)
            case .none:
                break
            }
        }

        if let error { throw error }
    }

    /// Try to send an element without suspending.
    ///
    /// - Parameter element: The element to send.
    /// - Returns: `true` if the element was sent, `false` if the buffer is full or channel is closed.
    @inlinable
    @discardableResult
    public func tryOne(_ element: Element) -> Bool {
        let action = channel.storage.withLock { state in
            state.trySend(element)
        }

        switch action {
        case .deliverToReceiver(let receiverCont, let element):
            receiverCont.resume(returning: (element, nil))
            return true
        case .buffered:
            return true
        case .rejectClosed, .rejectCancelled, .suspend:
            return false
        }
    }
}
