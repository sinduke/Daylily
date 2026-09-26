# 0026-006 Integration and Verification

Status: in-progress
Epic: 0026-real-business-and-sustained-operation

Goal:

- Integrate all five priorities and close only after the complete required checks finish.

Scope:

- Execute the corresponding authorized alpha.4 checklist slice.

Non-goals:

- A new published version tag, paid infrastructure, or a claim of production certification.

Steps:

- [x] 0026-006.1 Review and integrate task implementations and public contracts.
- [x] 0026-006.2 Update AIDEV, user guides, machine registry and unreleased changelog.
- [x] 0026-006.3 Pass local build/test/default-server smoke and affected external consumers.
- [ ] 0026-006.4 Commit/push the integrated candidate and pass macOS/Linux exact-revision CI plus the one-hour deployment.
- [ ] 0026-006.5 Audit resolver pins, logs and trial evidence; complete the execution checklist.

Architecture impact:

- Shared documentation and CI integration, preserving published releases and historical evidence.

Public API impact:

- None directly; integrated API changes are documented by their owning tasks.

AIDEV updates required:

- Workflow, project map, roadmap, registry and relevant user-facing validation guides.

Validation:

- All required CI jobs and runtime/deployment acceptance pass at the candidate revision; all task reports link real evidence.

Notes:

- Status remains in-progress until evidence is available. Twenty-four-hour soak is a later Beta gate.

Local integration evidence so far:

- Full Swift build/test/check passed: 74 tests in seven suites; no compiler warning in the final runtime build.
- Current external consumer path smoke passed eight tests plus runtime/macro HTTP and expected optional-path diagnostics; added alpha.4 resource APIs are exercised.
- Persistent external consumer path build and two unit tests passed. Original commerce path build/four tests/check passed.
- Default `swift run --skip-build` served GET /hello and POST /json/echo and exited zero on SIGTERM. An initial harness incorrectly passed --port to HelloDaylily (which has fixed default port); corrected to the documented default, with no application code change.
- Python compatibility suite passed 35 methods; generated-client HTTP passed ten groups. Baseline-only extended AI validation passed even with a nonexistent Codex path, so CI makes no model call. YAML parsing and whitespace validation passed.
- Independent P2/P5 review passed; P1 review identified a confirmed idempotency/catalog race, fixed with a full-key transaction lock. The deterministic two-HTTP-process regression returns 201/400/201 on the old path and 201/201/201 with matching original order on the fixed path; final 13-check HTTP/DB acceptance and two unit tests passed.
