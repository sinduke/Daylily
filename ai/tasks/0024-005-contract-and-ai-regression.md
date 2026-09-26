# 0024-005 Contract and AI Change Regression

Status: implemented
Epic: 0024-release-and-operational-readiness

Goal:

- Detect documented OpenAPI wire incompatibilities before publishing an application contract.
- Exercise genuinely generated old/new clients over HTTP.
- Measure six independent AI application edits from fixed starting fixtures, not reference-result replay.

Scope:

- OpenAPI 3.1 JSON subset compatibility checker and directional contract regression fixtures.
- Generated old/new clients and compatible updated server in an isolated SwiftPM package.
- Three application tasks, two fresh working copies per task, deterministic immutable acceptance checks.
- Per-attempt patch, transcript, wall time, token usage when reported, and explicit unknown cost.

Non-goals:

- Complete JSON Schema/OpenAPI validation, source compatibility of generated client symbols, model quality benchmarks, or paid API provisioning.

Steps:

- [x] 0024-005.1 Define directional subset and verify breaking/compatible/unsupported outcomes.
- [x] 0024-005.2 Run old/new generated clients against compatible updated server.
- [x] 0024-005.3 Implement reproducible independent AI edit runner and acceptance fixtures.
- [x] 0024-005.4 Execute six trials and record acceptance/time/usage/cost evidence.
- [x] 0024-005.5 Document limitations and hand shared CI/AIDEV integration to parent.

Architecture impact:

- No framework runtime or existing example source changes; regression tools operate on isolated consumers.

Public API impact:

- New developer validation commands only.

AIDEV updates required:

- Parent owns shared command indexes, registry, roadmap, release docs, and CI.

Validation:

- Deterministic compatibility fixtures and invalid/unsupported input checks.
- Real generated clients over localhost HTTP, built with Swift 6.3.2.
- Six separate Codex CLI invocations with acceptance run independently after each attempt.

Notes:

- Read AIDEV and OpenAI Docs skill; official noninteractive CLI and eval guidance used.
- Existing `ai/evals/application-changes` reference exercises remain unchanged and are not counted as model trials.
- CLI available as codex-cli 0.155.0-alpha.9.2 with ChatGPT login; default model gpt-6-astra with low reasoning.
- No commits/pushes in this delegated task.

Validation results — 2026-09-26:

- `python3 ai/evals/contracts/test_compatibility.py`: 29 directional supported/unsupported regression cases passed after review (the initial complete HTTP smoke ran the original 22 cases).
- Review found and fixed an explicit response status removed in favor of a new `default`: the old explicit decoder is now compared with that new fallback. Seven added test methods cover incompatible/compatible fallback, explicit decoder precedence, response-space narrowing, status ranges and invalid status keys. Status ranges such as `2XX` explicitly return unsupported instead of being treated as literal status codes.
- Independent CLI checks confirmed incompatible fallback exits `1`, compatible fallback exits `0`, and range statuses exit `2` with `compatible: null`. No Swift source changed in this checker-only correction; the successful generated-client HTTP evidence below remains applicable.
- `scripts/contract-regression-test.sh --mode path --workdir /tmp/daylily-contract-regression-final-20260926 --keep`: complete fresh-package run passed on Xcode 26.5/Swift 6.3.2/macOS arm64. Three independent Swift OpenAPI Generator 1.13.1 modules compiled; all four actual HTTP checks passed. Full log `/tmp/daylily-contract-regression-final-20260926.log`.
- The fixture explicitly installs official OpenAPIRuntime `ErrorHandlingMiddleware` so generated request decode failures map to 400. The first fixture run without the opt-in middleware returned 500; no framework behavior was changed to hide this ownership requirement.
- Six real `codex exec --json --ephemeral` trials used gpt-6-astra/low via an existing ChatGPT login, each in a new working directory. All six passed immutable acceptance with nonempty actual source patches; the three unmodified baselines independently failed as expected.
- All six event traces and patches were reviewed. They contain local fixture/docs reads and actual file edits, without reading the completed reference exercises. Both runs per task received identical fixture/task/test/doc content; each pair used separate conversation IDs and working directories.
- Two concurrent workers completed six trials in 177.072 seconds. Model-only wall times ranged 35.607–44.848 seconds; verification time is separately recorded per trial.
- Reported usage totals: 691174 input tokens, including 579456 cached input; 3502 output tokens and 84 reported reasoning-output tokens. Fields are retained as reported, not combined into a fabricated billing metric. Cost is null/unknown because CLI does not report a billable per-run amount.
- Versioned evidence: `ai/evals/repeated-changes/results/2026-09-26/` contains summary, per-attempt result JSON, source patch, compact event trace, acceptance log, and baseline results. Original transcript hashes are recorded; large command stdout is represented by hashes in exported traces.
- `bash -n`, Python syntax compilation, and `git diff --check` passed. Existing reference exercise sources, OpenAPI example sources, root Package.swift and shared CI/docs were not modified by this slice.

Parent integration:

- Add `python3 ai/evals/contracts/test_compatibility.py` to deterministic core checks and `scripts/contract-regression-test.sh` to path/revision candidate smoke as appropriate.
- Preserve `compatible-diff.json` and `breaking-diff.json` in CI evidence alongside dependency-record/Package.resolved and command logs.
- Real AI CLI trials intentionally do not run in automatic CI: reruns consume the signed-in account's quota and are an explicit evaluation action.
- New documentation: `docs/contract-and-ai-regression.md`; developer runner guide: `ai/evals/repeated-changes/README.md`.
- Code and delegated checks complete; task remains in-progress until parent shared AIDEV/CI integration and repository-wide checks finish.

Integration evidence:

- Shared AIDEV API/runtime/map/registry and user guides are synchronized. Local full build, 65 tests and behavior checks passed; default server HTTP/SIGTERM passed.
- The 300-second Linux/Caddy deployment passed 31,382 requests with no failures and clean teardown. See `docs/operational-trial-results.md`.
- Exact-candidate cross-platform CI is tracked separately by 0024-006; this task status records implemented and locally validated scope.
