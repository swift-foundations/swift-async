//
//  Async.Stream.Transducer.swift
//  swift-async
//
//  Closure-based witness for stateful stream transformation.
//
//  ## Design
//
//  A transducer is a composable transformation from one reducing function
//  to another. This implementation uses the protocol witness pattern
//  (closures instead of protocol conformance) for flexibility.
//
//  The term "transducer" comes from Clojure and functional programming,
//  where it describes transformations that:
//  - Are composable
//  - Can produce 0, 1, or many outputs per input
//  - Have a completion step for flushing state
//
//  ## References
//
//  - Clojure Transducers: https://clojure.org/reference/transducers
//  - Haskell foldl: https://hackage.haskell.org/package/foldl
//

public import Async_Primitives

extension Async.Stream {
    /// A stateful transformation for processing streams element-by-element.
    ///
    /// Transducers are state machines with three operations:
    /// 1. `initial` - Create initial state
    /// 2. `step` - Process one element, may produce outputs
    /// 3. `complete` - Finalize and flush remaining state
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Line transducer: buffers bytes until newline
    /// let lines = Async.Stream<UInt8>.Transducer<String, [UInt8]>(
    ///     initial: { [] },
    ///     step: { byte, state in
    ///         if byte == 0x0A {
    ///             defer { state = [] }
    ///             return [String(decoding: state, as: UTF8.self)]
    ///         }
    ///         state.append(byte)
    ///         return []
    ///     },
    ///     complete: { state in
    ///         state.isEmpty ? [] : [String(decoding: state, as: UTF8.self)]
    ///     }
    /// )
    ///
    /// // Usage with async stream
    /// let parsed = byteStream.transduce(with: lines)
    /// for await line in parsed {
    ///     print(line)
    /// }
    /// ```
    public struct Transducer<Output: Sendable, State: Sendable>: Sendable {
        /// Creates initial transducer state.
        @usableFromInline
        let initial: @Sendable () -> State

        /// Processes an element, returning any outputs produced.
        @usableFromInline
        let step: @Sendable (Element, inout State) -> [Output]

        /// Signals end of input, returning any final outputs.
        @usableFromInline
        let complete: @Sendable (inout State) -> [Output]

        /// Creates a transducer with the given closures.
        ///
        /// - Parameters:
        ///   - initial: Creates initial state.
        ///   - step: Processes an element, may produce outputs.
        ///   - complete: Flushes remaining state at end of input.
        @inlinable
        public init(
            initial: @escaping @Sendable () -> State,
            step: @escaping @Sendable (Element, inout State) -> [Output],
            complete: @escaping @Sendable (inout State) -> [Output]
        ) {
            self.initial = initial
            self.step = step
            self.complete = complete
        }
    }
}
