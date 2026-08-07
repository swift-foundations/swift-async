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
    /// Bounded concurrent evaluation of independent work.
    ///
    /// A fan-out often spawns a costly unit of work per item — a child
    /// process, a remote read, a full package build — so the bound is not
    /// a tuning preference. Unbounded, hundreds of concurrent starts
    /// thrash rather than finish sooner; serial, the wait dominates the
    /// wall clock and work that is progressing is indistinguishable from
    /// work that has hung.
    ///
    /// Results are returned in input order whatever order the work
    /// completes in, so a caller's report, findings, and short-circuit
    /// choice stay deterministic. Concurrency here changes when work
    /// happens, never what is measured or what is reported.
    public struct Fanout: Sendable {
        /// How many items are in flight at once.
        ///
        /// At least one, whatever bound the initializer was asked for.
        public let jobs: Swift.Int

        public init(jobs: Swift.Int) {
            self.jobs = Swift.max(1, jobs)
        }
    }
}
