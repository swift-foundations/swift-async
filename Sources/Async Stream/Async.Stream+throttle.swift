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

public import Async_Primitives

extension Async.Stream {
    /// Limits emissions to at most one per duration.
    ///
    /// Emits the first element, then ignores subsequent elements
    /// until the duration has passed.
    ///
    /// ## Usage
    /// ```swift
    /// let throttled = mouseMoves.throttle(.milliseconds(16))
    /// // At most 60fps
    /// ```
    ///
    /// - Parameter duration: The minimum time between emissions.
    /// - Returns: A throttled stream.
    public func throttle(_ duration: Duration) -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Throttle.State(stream: self, duration: duration)
            return Iterator {
                await state.next()
            }
        }
    }
}
