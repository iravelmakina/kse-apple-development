# Agent worklog

Use one entry for each tool-assisted or agent-assisted task. Do not include secrets, tokens, private
prompts, or sensitive session data.

Tool used throughout: **Claude Code (Anthropic, Opus 5)**, run locally in this repository.

---

## Entry 1 — Repository orientation notes

### Tool/agent task

Asked the agent to read the repository (`Package.swift`, `Sources/StudyPlanner/StudyPlanner.swift`,
`Tests/StudyPlannerTests/`, `README.md`, `TASKS_AND_GRADES.md`) and write `CLAUDE.md`: a short
orientation file recording the build/test commands, the package layout, the frozen public API, and
the behavioral rules the grader checks.

### Output reviewed

One new file, `CLAUDE.md`. Reviewed it against `TASKS_AND_GRADES.md` to confirm the behavioral rules
it lists (validation precedence, first-duplicate reporting, title-then-ID ordering, the four bonus
requirements) match the rubric, and against `Package.swift` to confirm the layout claims.

### Accepted/rejected/revised decision

Accepted after one revision round: the first draft used unexplained Swift/SwiftPM jargon ("target",
"value type", "synthesized conformance"). Requested a rewrite with a plain-language package-layout
section so the file is usable as personal reference, not only by the agent. No content about the
assignment's required behavior was changed — only how it is worded.

### Verification command/result

`swift build` — Build complete. (Documentation-only change; no behavior affected.)

### Artifact links

`CLAUDE.md`

---

## Entry 2 — Swift language explanation (no code produced)

### Tool/agent task

Asked the agent to explain `Sources/StudyPlanner/StudyPlanner.swift` line by line, with comparisons
to Go, covering `enum` raw values, `Optional`, `throws`, `Codable`, `private(set)`, `mutating`,
argument labels, and default parameter values.

### Output reviewed

Explanatory prose only, plus two throwaway scratch Swift files used to demonstrate behavior; neither
was added to the repository. Checked the claims against the real toolchain rather than taking them on
trust — in particular that `StudyCategory(rawValue:)` returns an `Optional` and that an unknown
category string makes `JSONDecoder` throw `DecodingError.dataCorrupted`.

### Accepted/rejected/revised decision

No repository changes to accept or reject. The explanation was used to decide the implementation
approach in Entry 3, so it is recorded here for completeness.

### Verification command/result

Scratch demonstration run with `swift <file>.swift`; observed output matched the explanation.

### Artifact links

None (nothing added to the repository).

---

## Entry 3 — Implementation of the six stubs and the bonus

### Tool/agent task

Asked the agent to plan, then implement, the required behavior: validation and error precedence,
`Codable` boundaries, duplicate detection and ordering, the queries and completion mutation, plus the
optional `importMerging(_:)` — and to add a student XCTest suite. Constraint given: do not change the
published public API or the supplied public tests.

### Output reviewed

Reviewed the full diff before accepting:

- `Sources/StudyPlanner/StudyPlanner.swift` — six stubs implemented; additions are
  `StudyItem.init(from:)`, `StudyPlan.init(from:)`, an internal `complete()`, a private static
  `normalized(_:)`, and two `private enum CodingKeys`.
- `Tests/StudyPlannerTests/StudyPlannerStudentTests.swift` — new file, 22 `test…` methods across five
  `XCTestCase` subclasses.

Confirmed independently that the public API is unchanged (`grep` of every `public` declaration
against the original template) and that the supplied tests are untouched
(`git diff --stat -- Tests/StudyPlannerTests/StudyPlannerPublicTests.swift` reports no change).

### Accepted/rejected/revised decision

Accepted, with these points checked rather than taken on trust:

- **Verified, not assumed:** the claim that `StudyPlan` cannot assign `isCompleted` directly was
  checked by compiling a minimal example, which failed with `setter is inaccessible` — confirming
  Swift's `private` scopes to the enclosing declaration, not the file. The internal `complete()`
  helper is therefore necessary, not stylistic.
- **Revised:** an early sketch of `decode(from:)` used `try?` to choose between the array and keyed
  JSON shapes. Rejected, because `try?` would swallow a genuine `.blankTitle` raised from inside a
  well-formed array and surface a misleading shape error instead. Replaced with a catch narrowed to a
  root-level `DecodingError.typeMismatch` (`context.codingPath.isEmpty`).
- **Judgment calls recorded, not hidden:** storing the untrimmed `title`, treating `isCompleted` as
  optional during decoding, and *not* re-normalizing order inside `importMerging` are documented with
  their reasoning in the Risks section of `PLAN.md`. The bonus-ordering decision resolves a genuine
  contradiction between task 3 and the bonus text; it is a reading, and `PLAN.md` says so.

### Verification command/result

`swift test` → **Executed 25 tests, with 0 failures** (3 supplied + 22 student-authored).

Note: bare `swift test` initially failed on this machine with
`unable to resolve module dependency: 'XCTest'` because `xcode-select` pointed at
`CommandLineTools`, which ships no XCTest. Runs were made with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`. This is a local toolchain
setting, not a property of the package.

### Artifact links

`artifacts/swift-test.txt` — captured passing run
`PLAN.md` — acceptance criteria, implementation steps, and risks
`Tests/StudyPlannerTests/StudyPlannerStudentTests.swift` — the student test suite
