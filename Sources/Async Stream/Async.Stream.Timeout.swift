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

// MARK: - Timeout

extension Async.Stream {
    /// Fails if no element arrives within the duration.
    ///
    /// The timeout resets after each element.
    ///
    /// ## Usage
    /// ```swift
    /// let withTimeout = stream.timeout(.seconds(5))
    /// // Completes with nil if no element for 5 seconds
    /// ```
    ///
    /// - Parameter duration: The maximum time to wait between elements.
    /// - Returns: A stream that completes on timeout.
    public func timeout(_ duration: Duration) -> Self {
        Self { [self] in
            let box = Async.Stream<Element>.Iterator.Box(self.makeAsyncIterator())

            return Iterator {
                @Dependency(\.clock) var clock
                let resolvedClock = clock
                do {
                    return try await withThrowingTaskGroup(of: Element?.self) { group in
                        group.addTask {
                            await box.next()
                        }
                        group.addTask {
                            try await resolvedClock.sleep(until: resolvedClock.now.advanced(by: duration))
                            throw CancellationError()
                        }

                        if let result = try await group.next() {
                            group.cancelAll()
                            return result
                        }

                        return nil
                    }
                } catch {
                    // Timeout
                    return nil
                }
            }
        }
    }
}
