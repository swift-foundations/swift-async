//
//  Async.Stream.Transducer.State.swift
//  swift-async
//
//  Actor managing transducer state for async stream transformation.
//

public import Async_Primitives

extension Async.Stream.Transducer {
    /// Actor managing transducer state.
    @usableFromInline
    actor Run: Sendable {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let transducer: Async.Stream<Element>.Transducer<Output, State>

        @usableFromInline
        var state: State

        @usableFromInline
        var pendingOutputs: [Output] = []

        @usableFromInline
        var upstreamDone: Bool = false

        @inlinable
        init(
            upstream: Async.Stream<Element>,
            transducer: Async.Stream<Element>.Transducer<Output, State>
        ) {
            self.box = Async.Stream<Element>.Iterator.Box(upstream.makeAsyncIterator())
            self.transducer = transducer
            self.state = transducer.initial()
        }
    }
}

extension Async.Stream.Transducer.Run {
    @inlinable
    func next() async -> Output? {
        // Return pending outputs first
        if !pendingOutputs.isEmpty {
            return pendingOutputs.removeFirst()
        }

        // Step more input
        while !upstreamDone {
            guard let element = await box.next() else {
                upstreamDone = true
                // Complete - flush remaining
                let finals = transducer.complete(&state)
                if !finals.isEmpty {
                    pendingOutputs = Array(finals.dropFirst())
                    return finals.first
                }
                return nil
            }

            let outputs = transducer.step(element, &state)
            if !outputs.isEmpty {
                pendingOutputs = Array(outputs.dropFirst())
                return outputs.first
            }
        }

        return nil
    }
}

// MARK: - Async.Stream Extension

extension Async.Stream {
    /// Transforms stream elements using a transducer.
    ///
    /// - Parameter transducer: The transducer to process elements.
    /// - Returns: Stream of transformed outputs.
    public func transduce<Output: Sendable, State: Sendable>(
        with transducer: Transducer<Output, State>
    ) -> Async.Stream<Output> {
        Async.Stream<Output> { [self] in
            let run = Async.Stream<Element>.Transducer<Output, State>.Run(
                upstream: self,
                transducer: transducer
            )
            return Async.Stream<Output>.Iterator {
                await run.next()
            }
        }
    }
}
