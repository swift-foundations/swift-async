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

public import Async_Primitives

extension Async.Stream.Share {
    /// Owns the shared upstream-forwarding task and the `Broadcast` used to
    /// fan it out to `share()`'s consumers.
    ///
    /// F-002: `share()`'s forwarding task used to be a bare fire-and-forget
    /// `Task` — no handle was retained anywhere, so it was never cancellable
    /// and kept consuming `upstream` forever, even once every consumer had
    /// gone away. Every stored property here is `let` (immutable after
    /// `init`), so this can be a plain `final class` rather than an actor:
    /// ARC alone drives the lifecycle. `Cursor` (one per subscriber) retains
    /// this `State`; once every `Cursor` plus the original `share()` closure
    /// release it, `deinit` cancels the forwarding task.
    ///
    /// Deliberately conservative scope, matching `Replay.Connection`: this
    /// ties forwarding-task lifetime to "the shared stream is *totally*
    /// abandoned," not to "subscriber count transiently hits zero." See
    /// REPORT.md deviations for why dynamic restart-on-resubscribe was ruled
    /// out of scope for wave 1.
    @usableFromInline
    final class State: Sendable {
        @usableFromInline
        let broadcast: Async.Broadcast<Element>

        private let forwardingTask: Task<Void, Never>

        @usableFromInline
        init(upstream: Async.Stream<Element>) {
            let broadcast = Async.Broadcast<Element>()
            self.broadcast = broadcast
            self.forwardingTask = Task {
                for await element in upstream {
                    broadcast.send(element)
                }
                broadcast.finish()
            }
        }

        deinit {
            forwardingTask.cancel()
        }
    }
}
