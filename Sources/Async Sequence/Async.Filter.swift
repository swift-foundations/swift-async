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
        let isIncluded: (Base.Element) async -> Bool

        @usableFromInline
        init(base: Base, isIncluded: @escaping (Base.Element) async -> Bool) {
            self.base = base
            self.isIncluded = isIncluded
        }

        public struct Iterator: AsyncIteratorProtocol {
            @usableFromInline
            var baseIterator: Base.AsyncIterator

            @usableFromInline
            let isIncluded: (Base.Element) async -> Bool

            @usableFromInline
            init(
                baseIterator: Base.AsyncIterator,
                isIncluded: @escaping (Base.Element) async -> Bool
            ) {
                self.baseIterator = baseIterator
                self.isIncluded = isIncluded
            }

            @inlinable
            public mutating func next() async -> Base.Element? {
                while let element = try? await baseIterator.next(isolation: #isolation) {
                    if await isIncluded(element) {
                        return element
                    }
                }
                return nil
            }
        }

        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(baseIterator: base.makeAsyncIterator(), isIncluded: isIncluded)
        }
    }
}

// MARK: - Conditional Sendable

extension Async.Filter: @unchecked Sendable
    where Base: Sendable, Base.Element: Sendable {}

extension Async.Filter.Iterator: @unchecked Sendable
    where Base.AsyncIterator: Sendable, Base.Element: Sendable {}
