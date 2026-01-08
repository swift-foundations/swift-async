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
    /// CombineLatest operations namespace.
    public struct CombineLatest: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {
    /// CombineLatest accessor for combine latest operations.
    public var combineLatest: CombineLatest { CombineLatest(base: self) }
}

extension Async.Stream.CombineLatest {
    /// Combines with another stream, emitting on either update.
    ///
    /// Emits a tuple with the latest value from each stream
    /// whenever either stream produces a new element.
    ///
    /// ## Usage
    /// ```swift
    /// let combined = stream1.combineLatest(stream2)
    /// for await (a, b) in combined { }
    /// ```
    ///
    /// - Parameter other: The stream to combine with.
    /// - Returns: A stream of tuples with latest values.
    public func callAsFunction<Other: Sendable>(
        _ other: Async.Stream<Other>
    ) -> Async.Stream<(Element, Other)> {
        Async.Stream<(Element, Other)> { [base] in
            let state = Async.Stream<(Element, Other)>.CombineLatest.State<Element, Other>()

            let task1 = Task {
                for await element in base {
                    await state.updateA(element)
                }
                await state.completeA()
            }

            let task2 = Task {
                for await element in other {
                    await state.updateB(element)
                }
                await state.completeB()
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
