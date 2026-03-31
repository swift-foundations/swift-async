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
    /// An asynchronous sequence that transforms elements and discards `nil` results.
    ///
    /// `CompactMap` preserves caller isolation — the transform runs on the actor
    /// that created the pipeline, not on the cooperative pool.
    ///
    /// Created by calling `.compactMap(_:)` on any `AsyncSequence`.
    ///
    // WORKAROUND: [API-NAME-001] Compound name — `Async.Map` is generic,
    // nesting `Compact` inside produces unusable type paths.
    // WHEN TO REMOVE: When Swift supports re-binding outer generics in nested types.
    public struct CompactMap<Base: AsyncSequence, Output>: AsyncSequence {
        public typealias Element = Output

        @usableFromInline
        let base: Base

        @usableFromInline
        let transform: Transform

        @usableFromInline
        enum Transform {
            case sync((Base.Element) -> Output?)
            case async((Base.Element) async -> Output?)
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
                while let element = try? await baseIterator.next(isolation: actor) {
                    let result: Output?
                    switch transform {
                    case .sync(let f): result = f(element)
                    case .async(let f): result = await f(element)
                    }
                    if let output = result {
                        return output
                    }
                }
                return nil
            }
        }

    }
}

// MARK: - AsyncSequence Conformance

extension Async.CompactMap {
    @inlinable
    public func makeAsyncIterator() -> Iterator {
        Iterator(baseIterator: base.makeAsyncIterator(), transform: transform)
    }
}

// MARK: - Sendable

// Async.CompactMap is intentionally non-Sendable. The transform closures
// are nonisolated(nonsending) — they inherit the caller's isolation and
// may capture non-Sendable actor-isolated state. Claiming Sendable would
// be unsound. For Sendable pipelines, use Async.Stream.map.compact
// (which requires @Sendable closures).
