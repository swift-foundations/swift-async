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
internal import Standard_Library_Extensions

extension Async.Stream.Combine {
    /// Combines with another stream, emitting on either update.
    ///
    /// Emits a tuple with the latest value from each stream
    /// whenever either stream produces a new element.
    ///
    /// ## Usage
    /// ```swift
    /// let combined = stream1.combine.latest(stream2)
    /// for await (a, b) in combined { }
    /// ```
    ///
    /// - Parameter other: The stream to combine with.
    /// - Returns: A stream of tuples with latest values.
    public func latest<Other: Sendable>(
        _ other: Async.Stream<Other>
    ) -> Async.Stream<(Element, Other)> {
        Async.Stream<(Element, Other)> { [base] in
            let state = Async.Stream<(Element, Other)>.Combine.State<Element, Other>()

            let task1 = Task {
                await state.run { state in
                    for await element in base {
                        state.updateA(element)
                    }
                    state.completeA()
                }
            }

            let task2 = Task {
                await state.run { state in
                    for await element in other {
                        state.updateB(element)
                    }
                    state.completeB()
                }
            }

            return Async.Stream<(Element, Other)>.Iterator {
                let result = await state.receive()
                if result == nil {
                    task1.cancel()
                    task2.cancel()
                }
                return result
            }
        }
    }
}
