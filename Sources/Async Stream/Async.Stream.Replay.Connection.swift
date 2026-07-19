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

extension Async.Stream.Replay {
    /// Owns the shared upstream-forwarding task started by `replay(bufferSize:)`.
    ///
    /// F-002: the forwarding task used to be a bare fire-and-forget `Task` with
    /// no handle retained anywhere in the package — there was no way to ever
    /// cancel it, so it kept pulling from `upstream` for as long as `upstream`
    /// itself kept producing, even after every subscriber had gone away.
    ///
    /// `Connection` is a plain, immutable-after-init `final class`: ARC alone
    /// drives its lifetime. The `replay(bufferSize:)` closure and every
    /// `Cursor` created from it retain the same `Connection` instance; once
    /// all of them are released, `deinit` cancels the forwarding task.
    ///
    /// Deliberately conservative scope: this ties forwarding-task lifetime to
    /// "the replay stream is *totally* abandoned" (every `Cursor` plus the
    /// original stream value gone), not to "subscriber count transiently hits
    /// zero." A live-restart-on-resubscribe policy was considered and rejected
    /// for wave 1 — re-iterating an arbitrary `upstream` a second time is not
    /// safe in general (cold, one-shot sources would replay from the
    /// beginning), and that risk is out of scope for this fix. See REPORT.md
    /// deviations.
    @usableFromInline
    final class Connection: Sendable {
        @usableFromInline
        let task: Task<Void, Never>

        @usableFromInline
        init(_ task: Task<Void, Never>) {
            self.task = task
        }

        deinit {
            task.cancel()
        }
    }
}
