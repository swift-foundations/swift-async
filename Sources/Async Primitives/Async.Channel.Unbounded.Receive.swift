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
import Synchronization

// MARK: - Receive Implementation

extension Async.Channel.Unbounded.Receive {
    /// Receive the next element from the channel.
    ///
    /// Suspends if the buffer is empty and the channel is not closed.
    /// Returns `nil` when the channel is closed and all elements have been drained.
    ///
    /// ## Cancellation Safety
    /// When the task is cancelled while waiting:
    /// - The waiter is immediately removed from the queue (O(n) deque rebuild)
    /// - The operation throws `Error.cancelled`
    /// - Cancelled tasks always make progress (no deadlock)
    ///
    /// The cancellation handler uses atomic take-and-clear to safely race with
    /// the continuation body. Both paths funnel through `pump(cancelling:)`.
    ///
    /// ## §5.3 Compliance
    /// Cancellation handlers do not decide outcomes independently.
    /// They call `pump(cancelling:)` which:
    /// - Mutates state under lock
    /// - Decides outcome precedence
    /// - Returns the continuation to resume
    /// The handler merely executes the returned action outside the lock.
    ///
    /// ## FIFO Waiter Queue
    /// Multiple tasks may wait concurrently. Waiters are served in FIFO order.
    /// Cancellation removes the specific waiter by ID, preserving order for others.
    ///
    /// - Returns: The next element, or `nil` if closed and drained.
    /// - Throws: `Error.cancelled` if the task is cancelled while waiting.
    public func callAsFunction() async throws(Async.Channel.Unbounded<Element>.Error) -> Element? {
        // Fast path under lock (no suspension needed)
        let fastResult: Outcome? = channel._state.withLock { state in
            if let element = state.buffer.take.front {
                return .element(element)
            }
            if state.`is`.closed {
                return .finished
            }
            return nil
        }

        if let result = fastResult {
            switch result {
            case .element(let e): return e
            case .finished: return nil
            case .cancelled: throw .cancelled
            }
        }

        // Slow path: must suspend
        // Publication slot for cancellation-safe ID publication/claim.
        // CRITICAL: onCancel can run at ANY time - before, during, or after continuation body.
        // We use atomic take-and-clear to safely race between continuation body and onCancel.
        let publication = Async.Publication<UInt64>()

        // Capture channel explicitly to avoid capturing self in @Sendable closure
        let channel = self.channel

        let result: Outcome = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let (immediate, id) = channel._state.withLock { state in
                    state.pump(receiving: continuation)
                }

                if let result = immediate {
                    continuation.resume(returning: result)
                    return
                }

                // Publish the installed ID (returned from same lock acquisition)
                if let id = id {
                    publication.publish(id)

                    // Close the early-cancellation window:
                    // If task was cancelled after install but before onCancel could see the ID,
                    // we must perform cancellation here.
                    if Task.isCancelled {
                        if let taken = publication.take() {
                            // §5.3: funnel through pump(cancelling:)
                            let cancelled = channel._state.withLock { state in
                                state.pump(cancelling: taken)
                            }
                            cancelled?.continuation.resume(returning: .cancelled)
                            return  // Exit immediately after cancellation resume
                        }
                    }
                }
                // Otherwise continuation stored, will be resumed by send/close/cancel pump
            }
        } onCancel: { [publication, channel] in
            // Atomically take the published ID
            guard let taken = publication.take() else { return }  // ID not yet published or already taken

            // §5.3: Call pump(cancelling:) which removes specific waiter by ID.
            // This guarantees progress - cancelled task always resumes.
            let cancelled = channel._state.withLock { state in
                state.pump(cancelling: taken)
            }

            // Resume cancelled receiver outside lock (if found)
            cancelled?.continuation.resume(returning: .cancelled)
        }

        switch result {
        case .element(let e): return e
        case .finished: return nil
        case .cancelled: throw .cancelled
        }
    }
}
