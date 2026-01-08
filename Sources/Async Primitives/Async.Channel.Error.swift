//
//  File.swift
//  swift-async
//
//  Created by Coen ten Thije Boonkkamp on 08/01/2026.
//

extension Async {
    /// Errors that can occur during channel operations.
    ///
    /// Note: Defined at `Async` level (not inside generic `Channel<Element>`)
    /// to work around Swift compiler IRGen crash with typed throws + async + nested generic error types.
    public enum _ChannelError: Swift.Error, Sendable, Equatable {
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

extension Async.Channel {
    public typealias Error = Async._ChannelError
}
