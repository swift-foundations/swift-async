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

import StandardsCollections

extension Async.Channel.Unbounded {
    /// Internal state for the unbounded channel.
    ///
    /// Manages the element buffer, waiter queue, and lifecycle flags.
    /// All mutations go through pump functions that return actions to execute outside the lock.
    struct State {
        /// Buffered elements waiting to be received.
        var buffer: Deque<Element> = .init()

        /// FIFO queue of waiting receivers.
        var receivers: Deque<Receiver> = .init()

        /// Receiver ID allocation.
        var receiver: ReceiverID = .init()

        /// Lifecycle flags.
        var `is`: Is = .init()
    }
}

// MARK: - Nested Types

extension Async.Channel.Unbounded {
    /// Receiver ID state.
    struct ReceiverID {
        /// Seed for allocating unique receiver IDs.
        var seed: UInt64 = 0
    }

    /// Lifecycle flags.
    struct Is {
        /// Whether the channel has been closed.
        var closed: Bool = false
    }
}

// MARK: - Pump Functions

extension Async.Channel.Unbounded.State {
    /// Single resumption funnel for send path.
    ///
    /// - Parameter element: The element to send.
    /// - Returns: `(deliver, accepted)` where:
    ///   - `deliver`: If non-nil, the receiver and outcome to resume with
    ///   - `accepted`: Whether the element was accepted (false if closed)
    ///
    /// The funnel fully owns outcome selection. No cancelled reaping needed
    /// because `pump(cancelling:)` eagerly removes cancelled waiters.
    mutating func pump(
        sending element: Element
    ) -> (deliver: (receiver: Async.Channel.Unbounded<Element>.Receiver, outcome: Async.Channel.Unbounded<Element>.Receive.Outcome)?, accepted: Bool) {
        guard !`is`.closed else { return (nil, false) }

        // Pop first receiver (all receivers are non-cancelled - cancellation eagerly removes)
        if let receiver = receivers.take.front {
            // Found waiting receiver - pump owns outcome selection
            return ((receiver, .element(element)), true)
        }
        // No waiting receiver, buffer the element
        buffer.push.back(element)
        return (nil, true)
    }

    /// Single resumption funnel for close path.
    ///
    /// - Returns: All receivers to resume with `.finished`.
    ///
    /// No cancelled tracking needed because `pump(cancelling:)` eagerly removes cancelled waiters.
    mutating func pump(
        closing: Void
    ) -> [Async.Channel.Unbounded<Element>.Receiver] {
        `is`.closed = true
        var result: [Async.Channel.Unbounded<Element>.Receiver] = []
        while let receiver = self.receivers.take.front {
            result.append(receiver)
        }
        return result
    }

    /// Single resumption funnel for receive path.
    ///
    /// - Parameter continuation: The continuation to install if suspension is needed.
    /// - Returns: `(immediate, id)` where:
    ///   - `immediate`: If non-nil, the outcome to return immediately (no suspension)
    ///   - `id`: If non-nil, the ID of the installed waiter (suspension installed)
    ///
    /// Outcome precedence:
    /// 1. Element wins if present in buffer
    /// 2. Finished wins if closed
    /// 3. Otherwise install waiter
    mutating func pump(
        receiving continuation: CheckedContinuation<Async.Channel.Unbounded<Element>.Receive.Outcome, Never>
    ) -> (immediate: Async.Channel.Unbounded<Element>.Receive.Outcome?, id: UInt64?) {
        // Check buffer first - element wins
        if let element = buffer.take.front {
            return (.element(element), nil)
        }
        // Check closed - finished wins
        if `is`.closed {
            return (.finished, nil)
        }
        // Must suspend - allocate ID and install waiter
        receiver.seed &+= 1
        let id = receiver.seed
        receivers.push.back(Async.Channel.Unbounded<Element>.Receiver(id: id, continuation: continuation))
        return (nil, id)
    }

    /// Single resumption funnel for cancellation path.
    ///
    /// Called from cancellation handler - removes specific waiter by ID.
    /// Returns the cancelled receiver to resume (ensures progress for cancelled task).
    ///
    /// - Parameter id: The ID of the waiter to cancel.
    /// - Returns: The removed receiver, or `nil` if not found.
    ///
    /// - Note: This rebuilds the deque to remove by ID (O(n)).
    ///   Cancellation is rare; correctness beats micro-optimization for "timeless infra."
    ///   Deque lacks `remove(at:)`, so we rebuild without the cancelled waiter.
    mutating func pump(
        cancelling id: UInt64
    ) -> Async.Channel.Unbounded<Element>.Receiver? {
        // Scan for the waiter with matching ID
        // Rebuild deque without the cancelled waiter
        var found: Async.Channel.Unbounded<Element>.Receiver? = nil
        var remaining: Deque<Async.Channel.Unbounded<Element>.Receiver> = .init()

        while let receiver = receivers.take.front {
            if receiver.id == id && found == nil {
                found = receiver
            } else {
                remaining.push.back(receiver)
            }
        }

        receivers = remaining
        return found
    }
}
