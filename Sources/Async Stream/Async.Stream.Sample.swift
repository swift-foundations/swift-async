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
    /// Sample accessor for sample operations.
    public var sample: Sample { Sample(base: self) }

    /// Sample operations namespace.
    public struct Sample: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream.Sample {
    /// Samples this stream when trigger emits.
    ///
    /// Emits the most recent element from this stream each time
    /// the trigger stream emits.
    ///
    /// ## Usage
    /// ```swift
    /// let sampled = values.sample.on(ticks)
    /// // Emits latest value whenever ticks emits
    /// ```
    ///
    /// - Parameter trigger: Stream that triggers sampling.
    /// - Returns: A stream of sampled elements.
    public func on<Trigger: Sendable>(
        _ trigger: Async.Stream<Trigger>
    ) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Sample.State<Trigger>(source: base, trigger: trigger)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }
}
