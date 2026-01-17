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

public import Reference_Primitives

extension Reference.Indirect.Unchecked where Value: AsyncIteratorProtocol {
    /// Advances to the next element and returns it, or nil if no next element exists.
    ///
    /// This extension enables using `Reference.Indirect.Unchecked` as a boxed async iterator,
    /// allowing non-Sendable iterators to be captured in `@Sendable` closures.
    @usableFromInline
    func next() async -> Value.Element? {
        try? await indirect.value.next()
    }
}
