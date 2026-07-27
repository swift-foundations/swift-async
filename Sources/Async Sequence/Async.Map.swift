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

extension Async {
    /// An asynchronous sequence that transforms elements using a closure.
    ///
    /// `Map` preserves caller isolation — closures run on the actor that
    /// created the pipeline, not on the cooperative pool. This is the
    /// concrete-type counterpart to `Async.Stream.map`, which type-erases.
    ///
    /// Created by calling `.map(_:)` on any `AsyncSequence`.
    public struct Map<Base: AsyncSequence, Output>: AsyncSequence {
        public typealias Element = Output

        @usableFromInline
        let base: Base

        @usableFromInline
        let transform: Transform

        @usableFromInline
        enum Transform {
            case sync((Base.Element) -> Output)
            case async((Base.Element) async -> Output)
        }

        @usableFromInline
        init(base: Base, transform: Transform) {
            self.base = base
            self.transform = transform
        }

        public struct Iterator: AsyncIteratorProtocol {
            @usableFromInline
            var baseIterator: Base.AsyncIterator

            @usableFromInline
            let transform: Transform

            @usableFromInline
            init(
                baseIterator: Base.AsyncIterator,
                transform: Transform
            ) {
                self.baseIterator = baseIterator
                self.transform = transform
            }

            @inlinable
            public mutating func next(
                isolation actor: isolated (any Actor)? = #isolation
            ) async -> Output? {
                guard let element = try? await baseIterator.next(isolation: actor) else {
                    return nil
                }
                switch transform {
                case .sync(let f): return f(element)
                case .async(let f): return await f(element)
                }
            }
        }

    }
}

// MARK: - AsyncSequence Conformance

extension Async.Map {
    @inlinable
    public func makeAsyncIterator() -> Iterator {
        Iterator(baseIterator: base.makeAsyncIterator(), transform: transform)
    }
}

// MARK: - Sendable

// Async.Map is intentionally non-Sendable. The transform closures are
// nonisolated(nonsending) — they inherit the caller's isolation and may
// capture non-Sendable actor-isolated state. Claiming Sendable would be
// unsound. For Sendable pipelines, use Async.Stream.map (which
// requires @Sendable closures).
