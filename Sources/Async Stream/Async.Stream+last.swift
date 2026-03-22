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
    /// Collects and emits only the last element.
    ///
    /// Note: This consumes the entire stream before emitting.
    ///
    /// ## Usage
    /// ```swift
    /// let last = stream.last()
    /// ```
    ///
    /// - Returns: A stream that emits only the last element.
    public func last() -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Last.State(stream: self)
            return Iterator {
                await state.next()
            }
        }
    }

    /// Collects and emits only the last element matching predicate.
    ///
    /// - Parameter predicate: A function to test elements.
    /// - Returns: A stream that emits the last matching element.
    public func last(
        where predicate: @escaping @Sendable (Element) -> Bool
    ) -> Self {
        filter(predicate).last()
    }
}
