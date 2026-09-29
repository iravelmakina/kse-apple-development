# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A graded university homework template (KSE "Apple Development", HW1). It is a Swift Package
library — `StudyPlanner` — whose domain logic is deliberately unimplemented: every method in
`Sources/StudyPlanner/StudyPlanner.swift` is a `fatalError(...)` stub, so the package **compiles
but its tests fail** until the behavior is written. Implementing those stubs is the assignment.

Grading is done by staff who clone the submitted commit and run **private hidden tests** against
the published public API. That makes API stability the hard constraint of this repo (see below).

## Commands

```sh
swift build                                              # compile
swift test                                               # full suite (the command the README mandates)
swift test --filter StudyPlannerPublicTests              # one test class
swift test --filter StudyPlannerPublicTests/testBlankTitleIsRejected   # one test method
```

Swift tools version 6.0 (Swift 6 language mode / strict concurrency). No external dependencies,
no linter, no CI workflow — `swift test` is the only verification gate.

## Package layout (Swift Package Manager)

`Package.swift` is the manifest — it is itself Swift code, not a config file, and it declares the
build graph:

- a **target** is a compilation unit (roughly: one module). This package has two — the library
  target `StudyPlanner` and the test target `StudyPlannerTests` that depends on it.
- SwiftPM finds a target's sources **by convention**: `Sources/<TargetName>/` and
  `Tests/<TargetName>/`. Adding a `.swift` file under those directories is enough; there is no file
  list to update.
- `resources: [.copy("Fixtures")]` copies `Tests/StudyPlannerTests/Fixtures/` into the compiled test
  bundle, so tests load `study-items.json` at runtime through `Bundle.module` rather than by file path.
- Tests say `@testable import StudyPlanner`, which grants access to `internal` declarations too — so
  a helper does not have to be `public` to be testable.
- `.build/` is generated output and is gitignored.

## Architecture

All production code lives in one file, `Sources/StudyPlanner/StudyPlanner.swift`:

- `StudyCategory` — `String`-backed enum (`reading`, `practice`, `project`); its raw values are the
  JSON contract used by `Tests/StudyPlannerTests/Fixtures/study-items.json`.
- `StudyPlanError` — the complete, `Equatable` error vocabulary. Hidden tests assert on these
  specific cases, so throw exactly these and never add a competing error type.
- `StudyItem` — a `struct`, so it has value semantics: assigning or passing one copies it, as with
  a Go struct (unlike a Go struct, there are no pointers to it here). Validation belongs in `init`, and because `StudyItem` is
  `Codable`, decoding must route through that same validation (write `init(from:)` rather than
  relying on the synthesized one) so invalid JSON throws instead of producing an invalid value.
  `isCompleted` is `public private(set)`, so completion is driven through `StudyPlan`, not by
  mutating the item from outside.
- `StudyPlan` — owns `private(set) var items` and enforces plan-level invariants: duplicate-ID
  rejection plus a deterministic stored order. Two decoding entry points exist by design:
  the compiler-generated ("synthesized") `Codable` conformance handles the **keyed** form (`{"items": [...]}`), while
  `decode(from:)` handles a **top-level JSON array** (the shape of the test fixture). Both must end
  up applying the same validation and ordering as `init(items:)`.

Behavioral rules the private grader checks (from `TASKS_AND_GRADES.md`) — treat these as the spec:

- Validation precedence: a blank title is reported **before** non-positive minutes when both are wrong.
  "Blank" means whitespace-only, not just empty.
- Duplicates: report the **first** duplicate ID encountered via `.duplicateID`.
- Ordering: deterministic sort by **title, then ID** (ID breaks title ties).
- `markCompleted(id:)` throws `.unknownID` for unknown IDs and is **idempotent** for known ones.
- `importMerging(_:)` (optional bonus, only scored once tasks 1–4 pass): reject duplicate IDs *within
  the incoming batch* without touching the plan; replace existing IDs **at their current positions**;
  append genuinely new IDs in **ascending ID order**; and be **atomic** — a failed import leaves the
  plan byte-for-byte unchanged (build into a local copy, assign on success).

## Hard constraints

- **Never change the public API or the supplied public tests.** The signatures in
  `StudyPlanner.swift` and the three tests in `Tests/StudyPlannerTests/StudyPlannerPublicTests.swift`
  are the grading contract. Additive internal helpers are fine; renaming, reordering parameters,
  adding or removing `throws`, or editing the starter tests breaks grading.
- Student-authored tests must be **added alongside** the starter tests (new `XCTestCase` subclasses or
  new `test…` methods in new files), never by modifying the existing ones. At least six are required.
  XCTest is the expected framework here, not swift-testing.
- Behavior must be deterministic — no reliance on dictionary iteration order or unstable sorts.

## Non-code deliverables

These files are graded (2 of the 12 points) and are not boilerplate to skip:

- `PLAN.md` — scope, acceptance criteria, test-first implementation steps, risks, and a dated record
  of each `swift test` run.
- `AGENT_WORKLOG.md` — **required disclosure** for any AI/agent assistance: the bounded task given,
  the output reviewed, what was accepted/rejected/revised and why, and the verification command plus
  its result. If you (Claude) make or propose changes here, the corresponding worklog entry is part
  of the work, not an optional extra. Never record secrets, tokens, or raw session data.
- `artifacts/` — curated, non-sensitive evidence (e.g. saved `swift test` output). Currently only
  `.gitkeep`; at least one real artifact is expected.
- `SUBMISSION.md` — the repo URL and the full 40-char SHA from `git rev-parse HEAD`.
