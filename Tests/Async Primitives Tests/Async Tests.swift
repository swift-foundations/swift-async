// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-runtime open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-runtime project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Async
import Testing

@Suite("Async")
struct AsyncTests {

    @Test("Async namespace exists")
    func namespaceExists() {
        _ = Async.self
        _ = Async.Channel.self
    }
}
