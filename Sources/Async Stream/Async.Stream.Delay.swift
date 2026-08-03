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
internal import Clocks_Dependencies
internal import Ownership_Primitives

// MARK: - Delay

extension Async.Stream {
    /// Delays each element by a duration.
    ///
    /// ## Usage
    /// ```swift
    /// let delayed = stream.delay(.seconds(1))
    /// // Each element arrives 1 second after it was produced
    /// ```
    ///
    /// - Parameter duration: The delay duration.
    /// - Returns: A stream with delayed elements.
    public func delay(_ duration: Duration) -> Self {
        Self { [self] in
            let box = Async.Stream<Element>.Iterator.Box(makeAsyncIterator())
            return Iterator {
                @Dependency(\.clock) var clock
                guard let element = await box.next() else { return nil }
                // swiftlint:disable:next no_try_optional - Clock.Any.sleep witnesses stdlib Swift.Clock.sleep, declared untyped async throws; no E for do throws(E) to name (rule-exemptions untyped-callee carve-out)
                try? await clock.sleep(for: duration)
                if Task.isCancelled { return nil }
                return element
            }
        }
    }
}
