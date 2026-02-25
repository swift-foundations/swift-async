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
    /// An asynchronous sequence that includes only elements matching a predicate.
    ///
    /// `Filter` preserves caller isolation — the predicate runs on the actor
    /// that created the pipeline, not on the cooperative pool.
    ///
    /// Created by calling `.filter(_:)` on any `AsyncSequence`.
    public struct Filter<Base: AsyncSequence>: AsyncSequence {
        public typealias Element = Base.Element

        @usableFromInline
        let base: Base

        @usableFromInline
        let predicate: Predicate

        @usableFromInline
        enum Predicate {
            case sync((Base.Element) -> Bool)
            case async((Base.Element) async -> Bool)
        }

        @usableFromInline
        init(base: Base, predicate: Predicate) {
            self.base = base
            self.predicate = predicate
        }

        public struct Iterator: AsyncIteratorProtocol {
            @usableFromInline
            var baseIterator: Base.AsyncIterator

            @usableFromInline
            let predicate: Predicate

            @usableFromInline
            init(
                baseIterator: Base.AsyncIterator,
                predicate: Predicate
            ) {
                self.baseIterator = baseIterator
                self.predicate = predicate
            }

            @inlinable
            public mutating func next(
                isolation actor: isolated (any Actor)? = #isolation
            ) async -> Base.Element? {
                while let element = try? await baseIterator.next(isolation: actor) {
                    let included: Bool
                    switch predicate {
                    case .sync(let f): included = f(element)
                    case .async(let f): included = await f(element)
                    }
                    if included {
                        return element
                    }
                }
                return nil
            }
        }

        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(baseIterator: base.makeAsyncIterator(), predicate: predicate)
        }
    }
}

// MARK: - Conditional Sendable

extension Async.Filter: @unchecked Sendable
    where Base: Sendable, Base.Element: Sendable {}

extension Async.Filter.Iterator: @unchecked Sendable
    where Base.AsyncIterator: Sendable, Base.Element: Sendable {}
