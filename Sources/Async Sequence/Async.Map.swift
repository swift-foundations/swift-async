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
        let transform: (Base.Element) async -> Output

        @usableFromInline
        init(base: Base, transform: @escaping (Base.Element) async -> Output) {
            self.base = base
            self.transform = transform
        }

        public struct Iterator: AsyncIteratorProtocol {
            @usableFromInline
            var baseIterator: Base.AsyncIterator

            @usableFromInline
            let transform: (Base.Element) async -> Output

            @usableFromInline
            init(
                baseIterator: Base.AsyncIterator,
                transform: @escaping (Base.Element) async -> Output
            ) {
                self.baseIterator = baseIterator
                self.transform = transform
            }

            @inlinable
            public mutating func next() async -> Output? {
                guard let element = try? await baseIterator.next(isolation: #isolation) else {
                    return nil
                }
                return await transform(element)
            }
        }

        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(baseIterator: base.makeAsyncIterator(), transform: transform)
        }
    }
}

// MARK: - Conditional Sendable

extension Async.Map: @unchecked Sendable
    where Base: Sendable, Base.Element: Sendable, Output: Sendable {}

extension Async.Map.Iterator: @unchecked Sendable
    where Base.AsyncIterator: Sendable, Base.Element: Sendable, Output: Sendable {}
