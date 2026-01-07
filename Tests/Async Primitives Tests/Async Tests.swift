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

@Suite("Runtime")
struct RuntimeTests {

    @Test("Runtime namespace exists")
    func namespaceExists() {
        _ = Runtime.self
        _ = Runtime.Mutex.self
        _ = Async.self
    }
}
