# Audit: swift-async

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/audit-foundations.md (2026-04-03)

**Pre-publication audit — P0/P1/P2 checks**

#### P1: Multi-type Files [API-IMPL-005]

**Moderate (3 types in one file)**:

| File | Types | Nature |
|------|-------|--------|
| `Sources/Async Stream/Async.Stream.Map.Flat.Latest.State.swift` | 3 | `Latest` namespace + `State` actor + `Transform` enum |
| `Sources/Async Sequence/Async.FlatMap.swift` | 3 | `FlatMap` + `Transform` enum + `Iterator` |
| `Sources/Async Sequence/Async.CompactMap.swift` | 3 | `CompactMap` + `Transform` enum + `Iterator` |
| `Sources/Async Sequence/Async.Map.swift` | 3 | `Map` + `Transform` enum + `Iterator` |
| `Sources/Async Sequence/Async.Filter.swift` | 3 | `Filter` + `Predicate` enum + `Iterator` |

**Pattern**: Most 3-type files follow a parent + nested child pattern (type + Iterator + Transform). The `Iterator` and `Transform` are tightly coupled to the sequence type.

**Minor (2 types in one file)**:

| File | Nature |
|------|--------|
| `Async.Stream.Distinct.State.swift` | `Distinct` struct + `State` actor |
| `Async.Stream.Map.Flat.State.swift` | `State` actor + `Transform` enum |

#### P1: Compound Type Names [API-NAME-001] — Documented Workarounds (no action needed)

| Type | Comment |
|------|---------|
| `Async.FlatMap` | `// WORKAROUND: [API-NAME-001]` — `Async.Map` is generic, nesting `Flat` inside it produces unusable type paths |
| `Async.CompactMap` | `// WORKAROUND: [API-NAME-001]` — same reason as FlatMap |

#### P2: Methods in Type Bodies [API-IMPL-008]

**Moderate (5-7 members in type body)**:

| File:Line | Type | Members |
|-----------|------|---------|
| `Async.Stream.Map.Flat.Latest.State.swift:23` | `State` | 7 |
| `Async.Stream.Combine.Latest.State.swift:17` | `State` | 7 |
| `Async.Stream.Buffer.Window.State.swift:20` | `State` | 6 |
| `Async.Stream.Sample.State.swift:18` | `State` | 6 |
| `Async.Stream.Transducer.State.swift:14` | `Run` | 6 |
| `Async.Stream.Merge.State.swift:17` | `State` | 5 |
| `Async.Stream.Latest.From.State.swift:18` | `State` | 5 |

**Pattern**: These are actor types holding stored state. Stored properties must be in the type body, so these are less concerning than computed properties or methods in type bodies.

---

### From: swift-institute/Research/modularization-audit-foundations-batch-A.md (2026-03-20)

**Modularization compliance — MOD-001 through MOD-014**

**Targets**: Async Sequence (9), Async Stream (55), Async (1 -- umbrella)

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | **FAIL** | No Core target. `Async Sequence` and `Async Stream` both independently depend on `Async Primitives` (L1). There is no intra-package Core that centralizes shared types. |
| MOD-002 Ext Dep Central | **FAIL** | Both variants independently import `Async Primitives`. `Async Stream` adds 4 more external deps. No centralization funnel. |
| MOD-003 Variant Decomp | PASS | `Async Sequence` and `Async Stream` are fully independent. Clean decomposition along async pattern axis. |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | PASS | `Async` (1 file: `Async.swift`) contains only `@_exported public import` statements for Async Primitives, Async Sequence, and Async Stream. Pure re-export. |
| MOD-006 Dep Min | PASS | Both variants declare only deps they need. |
| MOD-007 Graph Shape | PASS | Max depth = 1 (Async Sequence/Stream -> Async). Flat star topology. |
| MOD-008 Split Decision | **FAIL** | Async Stream has 55 files (operators, state types, iterators). This exceeds the guideline. Could split by operator category (combination, timing, buffering, transformation). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | N/A | No test support product. May be acceptable if async types do not need downstream test fixtures. |
| MOD-012 Naming | PASS | Names follow `Async {Variant}` pattern. `Async Sequence`, `Async Stream`, `Async` are correct for L3. |
| MOD-013 MARK | N/A | Only 3 source targets (below 5 threshold). |
| MOD-014 Cross-Pkg Traits | N/A | No cross-package optional integrations. |

**Detailed Findings**:

1. **F-ASYNC-001** (MOD-008): Async Stream has 55 files covering many reactive operators (CombineLatest, Debounce, FlatMap, Merge, Replay, Sample, Throttle, Timer, Zip, etc.). Each operator has its own state machine type. Consider splitting into `Async Stream Core` (base + iterator + buffer) and `Async Stream Operators` (all operator types).
2. **F-ASYNC-002** (MOD-001): No Core target. With only 2 variants that share Async Primitives externally, a Core may not add much value. This is a borderline case -- the package is small enough that a Core target may be over-engineering.
