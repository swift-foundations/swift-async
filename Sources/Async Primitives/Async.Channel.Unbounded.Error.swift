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
    /// Errors that can occur in unbounded channel operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The channel has been closed.
        ///
        /// Thrown by `send()` when attempting to send after the channel is closed.
        case closed

        /// The operation was cancelled.
        ///
        /// Thrown by `receive()` when the task is cancelled while waiting.
        case cancelled
    }
}
