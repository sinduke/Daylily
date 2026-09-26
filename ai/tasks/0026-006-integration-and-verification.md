# 0026-006 Integration and Verification

Status: implemented
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
- [x] 0026-006.4 Commit/push the integrated candidate and pass macOS/Linux exact-revision CI plus the one-hour deployment.
- [x] 0026-006.5 Audit resolver pins, logs and trial evidence; complete the execution checklist.

Architecture impact:

- Shared documentation and CI integration, preserving published releases and historical evidence.

Public API impact:

- None directly; integrated API changes are documented by their owning tasks.

AIDEV updates required:

- Workflow, project map, roadmap, registry and relevant user-facing validation guides.

Validation:

- All required CI jobs and runtime/deployment acceptance pass at the candidate revision; all task reports link real evidence.

Notes:

- Acceptance is complete with the exact-candidate evidence below. Twenty-four-hour soak is a later Beta gate.

Local integration evidence so far:

- Full Swift build/test/check passed: 74 tests in seven suites; no compiler warning in the final runtime build.
- Current external consumer path smoke passed eight tests plus runtime/macro HTTP and expected optional-path diagnostics; added alpha.4 resource APIs are exercised.
- Persistent external consumer path build and two unit tests passed. Original commerce path build/four tests/check passed.
- Default `swift run --skip-build` served GET /hello and POST /json/echo and exited zero on SIGTERM. An initial harness incorrectly passed --port to HelloDaylily (which has fixed default port); corrected to the documented default, with no application code change.
- Python compatibility suite passed 35 methods; generated-client HTTP passed ten groups. Baseline-only extended AI validation passed even with a nonexistent Codex path, so CI makes no model call. YAML parsing and whitespace validation passed.
- Independent P2/P5 review passed; P1 review identified a confirmed idempotency/catalog race, fixed with a full-key transaction lock. The deterministic two-HTTP-process regression returns 201/400/201 on the old path and 201/201/201 with matching original order on the fixed path; final 13-check HTTP/DB acceptance and two unit tests passed.

First external candidate attempt:

- Candidate `f4e3e8ab6a590026db105ab54db1dff49508a8af` was pushed for full CI run [36243752464](https://github.com/sinduke/Daylily/actions/runs/36243752464) and one-hour run [36243761973](https://github.com/sinduke/Daylily/actions/runs/36243761973). These attempts are retained as failed evidence, not accepted completion.
- Linux contract regression exposed a missing conditional `FoundationNetworking` import for the new raw URLSession checks. The fixture now imports it where available; the corrected exact-revision matrix verified the fix.
- Both business deployment attempts built the source-verified image and cleaned up without errors, but failed before traffic during readiness polling: Python 3.12 closes the socket when `HTTPResponse.read1` consumes a complete fixed-length response, and the next timeout update targeted its closed file descriptor. A focused regression and harness correction were added before repeating deployment acceptance, as recorded below.
- Artifact review also found the successful Linux persistent-consumer job uploaded only its log: `runner.temp` used a host path while the two dependency records lived at container `$RUNNER_TEMP`. The workflow now exports the runtime path through `GITHUB_ENV`, uploads from that path and asserts both records are nonempty before acceptance. Final artifact review verified their actual contents in the corrected run.

Corrected exact-candidate CI evidence:

- Candidate `1f8e0ea5f149b09cc398d302bf37c5cd63258452` passed [all 12 CI jobs](https://github.com/sinduke/Daylily/actions/runs/36244501153). Independent downloaded-artifact review confirmed 12/12 current resolver pins, 4/4 legacy alpha.1 pins, complete persistent-consumer artifacts, both platforms' 74 Swift/35 compatibility/13 HTTP harness tests, all four generated-client runs at 10/10 groups, and baseline-only AI checks without model calls. See [retained CI audit](../evals/deployment/results/2026-09-26-alpha4/ci-audit.md).
- The corrected short Linux deployment passed 60.162 seconds with 3,214 successful requests, 20 expected database outage responses, no unexpected failures, 38 resource samples and no cleanup errors. The parent independently recomputed source/harness/image/TLS hashes, traffic classifications and resource medians from raw artifacts.
- The separate [one-hour run](https://github.com/sinduke/Daylily/actions/runs/36244505313) completed successfully; its raw evidence and provenance were independently audited before closure.

Completed external acceptance:

- Tested revision `1f8e0ea5f149b09cc398d302bf37c5cd63258452`: [full CI](https://github.com/sinduke/Daylily/actions/runs/36244501153) 12/12 successful; [one-hour Linux run](https://github.com/sinduke/Daylily/actions/runs/36244505313) passed.
- 3600.175 seconds; 223,821 successful requests; 20 expected database 503s; zero unexpected failures; 494 resource records (493 complete samples and one planned restart gap); peak RSS 36,248 KiB; zero cleanup errors.
- Raw data/provenance/resolver audit passed. See [acceptance results](../../docs/alpha4-acceptance-results.md). This closes the authorized alpha.4 checklist without creating a new version tag.
