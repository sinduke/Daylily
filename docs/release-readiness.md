# Release Readiness

Daylily is experimental. The latest published prerelease is [0.1.0-alpha.3](https://github.com/sinduke/Daylily/releases/tag/0.1.0-alpha.3). Alpha.3 packages operation deadlines, graceful draining and transfer observation. Read the [alpha.3 migration guide](migration-alpha3.md) and [operational guide](operational-readiness.md).

## Validated alpha.4 candidate

The current checkout adds per-write deadlines/bounded observation, explicit nullable contracts and an independent persistent commerce consumer. [Epic 0026](../ai/epics/0026-real-business-and-sustained-operation.md) is complete: candidate `1f8e0ea5f149b09cc398d302bf37c5cd63258452` passed all 12 CI jobs and a measured one-hour external Linux run, with resolver and raw evidence audit. See [candidate semantics](alpha4-candidate.md) and [acceptance results](alpha4-acceptance-results.md). These changes are not yet a published tag.

## Published alpha.3

Runtime candidate `3bad369331e05231a0c644f148cb59be5f7dc898` passed [all nine integration CI jobs](https://github.com/sinduke/Daylily/actions/runs/36212918755). Preparation added versioned release documentation and current-profile checks for the new public APIs; exact-release CI also runs the generated-client contract regression. Commit `cfa835792cca3cce614999ddc7adca290015a801` passed [all nine preparation jobs](https://github.com/sinduke/Daylily/actions/runs/36216710327) before the annotated alpha.3 tag and GitHub prerelease were published. [Exact-tag validation](https://github.com/sinduke/Daylily/actions/runs/36217281415) passed **all 11 jobs**: core/path/revision/legacy/release on macOS and Linux, plus Linux proxy deployment. Downloaded release artifacts confirm all ten Package.resolved files (five consumers per platform) resolve version `0.1.0-alpha.3` at `cfa835792cca3cce614999ddc7adca290015a801`. Both release consumers pass eight external tests including operational APIs/four HTTP server entry points, and both generated-client contract runs pass all four HTTP scenarios. See [task 0025-001](../ai/tasks/0025-001-publish-alpha3.md).

## Published alpha.2

The completed reliability candidate `7d56798` passed [eight CI jobs](https://github.com/sinduke/Daylily/actions/runs/36209852394). Release preparation `f0d53421981e42e423e0b53b4f6a5dc3460bec81` then independently passed [eight jobs](https://github.com/sinduke/Daylily/actions/runs/36211564375) before the annotated alpha.2 tag was published on 2026-09-26.

[Exact-tag validation](https://github.com/sinduke/Daylily/actions/runs/36212096436) passed all **ten** jobs: core/path/revision/legacy/release on macOS and Linux. Alpha.2 core has 49 tests. Release jobs build consumer, template, commerce and generated OpenAPI HTTP examples. Downloaded consumer/template/commerce resolver records on both platforms confirm version `0.1.0-alpha.2` at `f0d53421981e42e423e0b53b4f6a5dc3460bec81`; legacy alpha.1 remains independently covered.

The later operational changes do not modify this tag. Their local tests and deployment evidence are recorded in [operational trial results](operational-trial-results.md), and candidate `3bad369331e05231a0c644f148cb59be5f7dc898` passed [all nine integration CI jobs](https://github.com/sinduke/Daylily/actions/runs/36212918755). Both platforms passed 65 Swift tests and 29 contract checks; both exact-revision suites verified five external packages. The separate clean Linux deployment job passed all functional scenarios and 30 seconds of sustained traffic.

## Supported validation environment

- Swift tools minimum: 6.3; tested compiler: Swift 6.3.2.
- macOS 14+ package platform; CI uses macos-26 with Xcode 26.5 selected explicitly.
- Linux CI uses ubuntu-24.04 with the official `swift:6.3.2-noble` image.
- SwiftSyntax starts at stable 603.0.1 and remains in the 603 major line.
- Local Swift Testing command: `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`.

## Candidate validation

The two platform matrices independently run core, path consumer, exact candidate revision consumer, and legacy alpha.1 consumer suites. Core checks also validate the compatibility checker; path/revision/release suites generate old/new contracts and run real HTTP regressions. A separate Linux job runs the reverse-proxy deployment with 30 seconds of sustained traffic. Two additional persistent-consumer jobs verify the independent database application on macOS/Linux, and a separate business deployment job runs 60 seconds of verified-TLS API/SSE/database traffic. The one-hour gate is dispatched with `business_trial_seconds=3600` and `business_only=true` against the same candidate. Core also runs 13 HTTP harness regressions and baseline-only AI fixture checks without model calls. Independent jobs continue when another fails. Toolchain, resolver pins, and smoke logs are uploaded as artifacts.

Current candidate revision consumers use the checked-out Git commit through a local Git URL. This tests actual SwiftPM source-control resolution even for a PR merge commit without a public tag. Working tree path tests do not prove that a release includes those changes.

```sh
swift build
swift test
swift run --skip-build HelloDaylily --check
scripts/consumer-smoke-test.sh --mode path --profile current
scripts/template-smoke-test.sh --mode path
scripts/example-smoke-test.sh --mode path
scripts/openapi-smoke-test.sh --mode path
scripts/ai-exercises-smoke-test.sh
python3 ai/evals/contracts/test_compatibility.py
python3 scripts/test-sustained-http.py
scripts/contract-regression-test.sh --mode path
python3 scripts/deployment-trial.py --duration 300 --artifacts /tmp/daylily-deployment
scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1 --profile legacy-alpha1
scripts/template-smoke-test.sh --mode release --version 0.1.0-alpha.1
```

All source-control consumers record the resolved revision. Release consumers use exact versions. `--profile current` selects current API coverage independently of dependency source; `legacy-alpha1` is only for the first release's older API surface. Simply changing `--version` must not suppress new capability checks. The current profile now requires alpha.4 candidate resource APIs; to reproduce alpha.2 or alpha.3 consumption, use the smoke scripts from the corresponding tag.

The current consumer includes macro dependencies, middleware, optional query/header HTTP behavior, an expected compile failure for optional path inputs, SwiftLog, ServiceLifecycle, HTTP Types, and OpenAPI transport. It also exercises operational configuration, all three transfer observers, and actual HTTP observation through both Application.run overloads and both ServiceLifecycle entry points. The OpenAPI example runs actual generated client/server code over HTTP. The template and commerce example are separately compiled as external packages.

## Ready for external trial

- Runtime and macro routing, middleware, keyed dependencies, typed inputs, JSON.
- One-shot request streams and demand-driven response streams, SSE, and bounded collection.
- Explicit OpenAPI schemas/security components and optional generated-server transport.
- Optional SwiftLog, ServiceLifecycle, and HTTP Types integrations.
- Lifecycle failure aggregation, all teardown hooks attempted once, and cancellation tests.
- In-memory testing, real-socket regression tests, and fixed application-change exercises.

## Known limits

- Public APIs are experimental; use the docs corresponding to your dependency version.
- HTTP/1.1 only; no built-in TLS or HTTP/2. Alpha.2 has no operation deadlines; alpha.3 adds header/upload idle limits and bounded graceful drain.
- Cooperative cancellation cannot forcibly stop handler code that ignores cancellation.
- `body` and `bodyString` are buffered compatibility views; streams require bounded async helpers.
- OpenAPI validation covers the supported explicit schema subset, not the complete OpenAPI/JSON Schema standard.
- Mixed generated path templates such as `{name}.zip` are rejected.
- `@Security` is metadata only; applications own authentication middleware.
- Deep Swift schema derivation, keyless dependency inference, optional path segments, and managed `ApplicationService` runtime APIs remain deferred.
- ORM, queues, WebSocket, public-cloud deployment automation and published benchmarks remain future work. The container deployment trial does not establish production capacity or long-duration stability.

## Release gate

1. Finish and review all task slices; update AIDEV and the machine-readable registry.
2. Pass the full macOS/Linux matrix on the exact candidate commit.
3. Give the changelog a versioned section and state support/migration notes clearly.
4. Tag using semver prerelease form only after the candidate is validated.
5. Dispatch CI with `release_version` to run the identical current capability set against the exact published version, including commerce and generated OpenAPI examples.
6. Preserve old alpha.1 coverage independently; never infer new API validation from the legacy suite.
