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

extension Async.Channel.Unbounded.Receive {
    /// The outcome of a receive operation.
    ///
    /// Used internally by the pump functions to communicate results
    /// that will be translated to the public API (Element?, throws Error).
    enum Outcome {
        /// An element was successfully received.
        case element(Element)

        /// The channel is closed and drained.
        case finished

        /// The receive was cancelled.
        case cancelled
    }
}
