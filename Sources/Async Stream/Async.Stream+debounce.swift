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
    /// Emits only after a quiet period with no new elements.
    ///
    /// When an element arrives, starts a timer. If another element arrives
    /// before the timer expires, restarts the timer. Only emits when the
    /// timer expires without interruption.
    ///
    /// ## Usage
    /// ```swift
    /// let debounced = searchText.debounce(.milliseconds(300))
    /// // Only emits after 300ms of no typing
    /// ```
    ///
    /// - Parameter duration: The quiet period to wait.
    /// - Returns: A debounced stream.
    public func debounce(_ duration: Duration) -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Debounce.State(stream: self, duration: duration)
            return Iterator {
                await state.next()
            }
        }
    }
}
