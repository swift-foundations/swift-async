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
    public struct CompactMap<Base: AsyncSequence, Output>: AsyncSequence {
        public typealias Element = Output

        @usableFromInline
        let base: Base

        @usableFromInline
        let transform: (Base.Element) async -> Output?

        @usableFromInline
        init(base: Base, transform: @escaping (Base.Element) async -> Output?) {
            self.base = base
            self.transform = transform
        }

        public struct Iterator: AsyncIteratorProtocol {
            @usableFromInline
            var baseIterator: Base.AsyncIterator

            @usableFromInline
            let transform: (Base.Element) async -> Output?

            @usableFromInline
            init(
                baseIterator: Base.AsyncIterator,
                transform: @escaping (Base.Element) async -> Output?
            ) {
                self.baseIterator = baseIterator
                self.transform = transform
            }

            @inlinable
            public mutating func next() async -> Output? {
                while let element = try? await baseIterator.next(isolation: #isolation) {
                    if let output = await transform(element) {
                        return output
                    }
                }
                return nil
            }
        }

        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(baseIterator: base.makeAsyncIterator(), transform: transform)
        }
    }
}

// MARK: - Conditional Sendable

extension Async.CompactMap: @unchecked Sendable
    where Base: Sendable, Base.Element: Sendable, Output: Sendable {}

extension Async.CompactMap.Iterator: @unchecked Sendable
    where Base.AsyncIterator: Sendable, Base.Element: Sendable, Output: Sendable {}
