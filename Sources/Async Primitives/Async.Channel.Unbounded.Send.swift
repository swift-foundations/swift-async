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

import Synchronization

// MARK: - Send Operations

extension Async.Channel.Unbounded {
    /// Send an element to the channel.
    ///
    /// If a consumer is awaiting via `receive()`, resumes it immediately.
    /// Otherwise, queues the element for later consumption.
    ///
    /// - Parameter element: The element to send.
    /// - Throws: `Error.closed` if the channel has been closed.
    public func send(_ element: Element) throws(Error) {
        // Pump under lock - returns actions (pump owns outcome selection)
        let (deliver, accepted) = _state.withLock { state in
            state.pump(sending: element)
        }

        guard accepted else { throw .closed }

        // Resume with outcome returned by pump (funnel owns selection)
        if let (receiver, outcome) = deliver {
            receiver.continuation.resume(returning: outcome)
        }
    }

    /// Send multiple elements to the channel.
    ///
    /// Sends each element individually. If consumers are awaiting,
    /// resumes them in order as elements are sent.
    ///
    /// - Parameter elements: The elements to send.
    /// - Throws: `Error.closed` if the channel has been closed.
    /// - Note: Stops on first error; some elements may have been sent.
    public func send<S: Sequence>(contentsOf elements: S) throws(Error) where S.Element == Element {
        for element in elements {
            try send(element)
        }
    }
}
