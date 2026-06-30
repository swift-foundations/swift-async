# swift-async

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Composable asynchronous streams and isolation-preserving `AsyncSequence` operators for Swift, built around a concrete `Async.Stream` type that composes through reactive combinators without type erasure.

---

## Key Features

- **Concrete `Async.Stream<Element>`** — a single `Sendable` `AsyncSequence` type that can be stored, passed around, and composed without `any AsyncSequence` erasure or generic type explosion.
- **Reactive combinators** — `merge`, `zip`, `combine.latest`, `debounce`, `throttle`, `sample`, `scan`, `delay`, and `timeout` over the concrete stream type.
- **Multicast** — `share()` and `replay` give multiple consumers a single upstream subscription instead of one per `for await`.
- **Isolation-preserving sequence operators** — `map`, `filter`, `compactMap`, and `flatMap` overloads that accept synchronous closures and run inline on the caller's actor rather than hopping to the cooperative pool.
- **Nested-accessor API** — variant transforms live under accessors (`stream.map.compact`, `stream.map.flat.latest`, `stream.zip(other)`) instead of compound method names.
- **Stream constructors** — build a stream from a sequence, an interval, a timer, or any existing `AsyncSequence` via `.from`, `.interval`, `.just`, `.empty`, and `.never`.

---

## Quick Start

A stream assembled from an interval and a stream built from a literal sequence are the *same* concrete type — `Async.Stream<String>` — so `merge` composes them uniformly. Without a concrete stream type, combining heterogeneously-constructed async sequences forces `any AsyncSequence` erasure or a bespoke merging `AsyncIteratorProtocol`:

```swift
import Async

let ticks = Async.Stream.interval(.seconds(1))
    .map { "tick #\($0)" }                  // Async.Stream<String>

let messages = Async.Stream.from(["ping", "pong"])  // Async.Stream<String>

let merged = Async.Stream.merge(ticks, messages)    // Async.Stream<String>

for await line in merged {
    print(line)
}
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-async.git", branch: "main")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Async", package: "swift-async")
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26.

---

## Architecture

The `Async` umbrella product re-exports the stream type, the sequence operators, and the underlying async coordination primitives. Narrower products are available when only one surface is needed.

| Product | Import | When to import |
|---------|--------|----------------|
| `Async` | `import Async` | The umbrella — the concrete stream type, the `AsyncSequence` operators, and the coordination primitives in one import. |
| `Async Sequence` | `import Async_Sequence` | Only the isolation-preserving lazy operators (`map` / `filter` / `compactMap` / `flatMap`) over any `AsyncSequence`. |
| `Async Stream` | `import Async_Stream` | Only the concrete `Async.Stream` type and its reactive combinators. |
| `Async Test Support` | `import Async_Test_Support` | Test targets exercising async streams. |

---

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at first public flip.*
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE](LICENSE.md).
