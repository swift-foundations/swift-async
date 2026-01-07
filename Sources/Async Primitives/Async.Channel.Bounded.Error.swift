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

extension Async.Channel {
    /// Errors that can occur during channel operations.
    ///
    /// Note: Defined at `Async.Channel` level (not inside generic `Bounded<Element>`)
    /// to work around Swift compiler IRGen crash with typed throws + async + nested generic error types.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The channel has been closed.
        ///
        /// Thrown when attempting to send to a closed channel.
        case closed

        /// The operation was cancelled.
        ///
        /// Thrown when the task is cancelled while waiting.
        case cancelled
    }
}

extension Async.Channel.Bounded {
    /// Errors that can occur during bounded channel operations.
    public typealias Error = Async.Channel.Error
}
