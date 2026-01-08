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

extension Async.Channel.Unbounded {
    /// A waiting receiver in the FIFO queue.
    ///
    /// Each receiver has a unique ID for identification during cancellation.
    struct Receiver {
        /// Unique identifier for this receiver.
        let id: UInt64

        /// The continuation to resume when an element is available.
        let continuation: CheckedContinuation<Receive.Outcome, Never>
    }
}
