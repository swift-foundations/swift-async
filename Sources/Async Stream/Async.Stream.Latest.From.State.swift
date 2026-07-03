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
public import Ownership_Primitives
internal import Standard_Library_Extensions

extension Async.Stream.Latest {
    /// Internal state for withLatestFrom.
    @usableFromInline
    actor State<Other: Sendable> {
        @usableFromInline
        var latestOther: Other?

        @usableFromInline
        var sourceBox: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        var otherTask: Task<Void, Never>?

        @usableFromInline
        var started: Bool = false

        @usableFromInline
        let other: Async.Stream<Other>

        @usableFromInline
        init(source: Async.Stream<Element>, other: Async.Stream<Other>) {
            self.sourceBox = Async.Stream<Element>.Iterator.Box(source.makeAsyncIterator())
            self.other = other
        }
    }
}

extension Async.Stream.Latest.State {
    @usableFromInline
    func startOtherTask() {
        guard !started else { return }
        started = true
        // Hoist the member into a local: an implicit-self reference
        // (`other` = self.other) inside the `run` closure captures the
        // actor alongside the explicit `isolated Self` parameter, and
        // SILGen traps on asserts toolchains ("building SIL function
        // type with multiple isolated parameters", ASTContext.cpp:5421).
        let other = self.other
        otherTask = Task { [self] in
            await self.run { state in
                for await element in other {
                    await state.updateLatestOther(element)
                }
            }
        }
    }

    @usableFromInline
    func updateLatestOther(_ element: sending Other) async {
        latestOther = element
    }

    @usableFromInline
    func next() async -> (Element, Other)? {
        startOtherTask()

        while true {
            guard let element = await sourceBox.next() else {
                otherTask?.cancel()
                return nil
            }

            // Only emit if we have a latest from other
            if let other = latestOther {
                return (element, other)
            }
            // Skip until we have a value from other
        }
    }
}
