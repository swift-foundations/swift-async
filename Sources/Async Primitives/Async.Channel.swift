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

extension Async {
    /// Namespace for channel primitives.
    ///
    /// Channels provide structured communication between concurrent tasks.
    /// Available channel types:
    /// - `Unbounded`: Unlimited buffer, sync send, async receive
    /// - `Bounded`: Capacity-limited buffer with backpressure
    public enum Channel {}
}
