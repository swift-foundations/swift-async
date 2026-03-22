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
    /// An asynchronous sequence that concatenates inner sequences produced by a transform.
    ///
    /// `FlatMap` preserves caller isolation — the transform runs on the actor
    /// that created the pipeline, not on the cooperative pool. Inner sequences
    /// are consumed serially (one at a time, in order).
    ///
    /// Created by calling `.flatMap(_:)` on any `AsyncSequence`.
    ///
    // WORKAROUND: [API-NAME-001] Compound name — `Async.Map` is generic,
    // nesting `Flat` inside produces unusable type paths.
    // WHEN TO REMOVE: When Swift supports re-binding outer generics in nested types.
    public struct FlatMap<Base: AsyncSequence, Segment: AsyncSequence>: AsyncSequence {
        public typealias Element = Segment.Element

        @usableFromInline
        let base: Base

        @usableFromInline
        let transform: Transform

        @usableFromInline
        enum Transform {
            case sync((Base.Element) -> Segment)
            case async((Base.Element) async -> Segment)
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
            var currentIterator: Segment.AsyncIterator?

            @usableFromInline
            init(
                baseIterator: Base.AsyncIterator,
                transform: Transform
            ) {
                self.baseIterator = baseIterator
                self.transform = transform
                self.currentIterator = nil
            }

            @inlinable
            public mutating func next(
                isolation actor: isolated (any Actor)? = #isolation
            ) async -> Segment.Element? {
                while true {
                    if var inner = currentIterator {
                        if let element = try? await inner.next(isolation: actor) {
                            currentIterator = inner
                            return element
                        }
                        currentIterator = nil
                    }

                    guard let base = try? await baseIterator.next(isolation: actor) else {
                        return nil
                    }

                    let segment: Segment
                    switch transform {
                    case .sync(let f): segment = f(base)
                    case .async(let f): segment = await f(base)
                    }
                    currentIterator = segment.makeAsyncIterator()
                }
            }
        }

    }
}

// MARK: - AsyncSequence Conformance

extension Async.FlatMap {
    @inlinable
    public func makeAsyncIterator() -> Iterator {
        Iterator(baseIterator: base.makeAsyncIterator(), transform: transform)
    }
}

// MARK: - Conditional Sendable

extension Async.FlatMap: @unchecked Sendable
    where Base: Sendable, Base.Element: Sendable, Segment: Sendable {}

extension Async.FlatMap.Iterator: @unchecked Sendable
    where Base.AsyncIterator: Sendable, Base.Element: Sendable,
          Segment: Sendable, Segment.AsyncIterator: Sendable {}
