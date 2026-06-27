---
composition_root: App/Sources/**
---

# Native iOS SPM boundary rules

These rules teach the factory how to decompose native iOS work into
`Scope:` lines that `TaskScopeGate` can enforce. They use Swift Package Manager
targets and modules — not .NET feature folders or contract assemblies.

## Module vocabulary

- **Package** — a Swift package rooted at `Packages/<Pkg>/` with its own
  `Package.swift`.
- **Target** — a library, executable, or test target declared in
  `Package.swift`. Production code lives under `Sources/<Target>/`;
  tests live under `Tests/<Target>Tests/` (or the test target name your
  manifest declares).
- **App shell** — the SwiftUI (or UIKit) application target that wires
  packages together. Treat it as the composition root when a task touches
  DI, navigation wiring, or app entry points.

## Writable `Scope: paths=` globs

Emit repo-root-relative globs that match exactly one package target (or
the app shell) per developer task:

| Surface | Glob pattern | Example |
| --- | --- | --- |
| Package source | `Packages/<Pkg>/Sources/<Target>/**` | `Packages/CounterFeature/Sources/CounterFeature/**` |
| Package tests | `Packages/<Pkg>/Tests/<Target>Tests/**` | `Packages/CounterFeature/Tests/CounterFeatureTests/**` |
| App shell | `App/Sources/<AppTarget>/**` | `App/Sources/CounterApp/**` |

When a task changes both production and test code for the same target,
include **both** globs in a comma-separated `paths=` list.

## Decomposer checklist

1. Name `module=` after the package or app target being edited (e.g.
   `CounterFeature`, `CounterApp`).
2. Prefer one package target per task; split cross-package integration
   into a dedicated wiring task whose `paths=` includes
   `composition_root` (`App/Sources/**`) when app entry or DI changes.
3. Do **not** default to modular-monolith .NET feature-folder or
   contract-assembly vocabulary — native iOS tasks scope SPM trees only.
4. XcodeGen project files (`project.yml`, generated `.xcodeproj`) and
   shared scripts are out of scope unless the task explicitly owns them;
   keep product logic scoped to SPM source and test trees above.

## `TaskScopeGate` reminders

- Changed files must match at least one declared `paths=` glob.
- `contracts=frozen` blocks edits under frozen contract surfaces when a
  repo also hosts .NET assemblies alongside Swift packages.
- Shared build infrastructure and generated artifacts follow the core
  gate allowlists documented in the orchestrator fallback.
