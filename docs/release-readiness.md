# Release Readiness

Daylily is experimental. The published release is `0.1.0-alpha.1`; current-checkout capabilities are listed in [Reliability and streaming](reliability-and-streaming.md). A new alpha candidate must pass the complete CI matrix before tagging. A successful local test run is not a substitute for that gate.

## Supported validation environment

- Swift tools minimum: 6.3; tested compiler: Swift 6.3.2.
- macOS 14+ package platform; CI uses macos-26 with Xcode 26.5 selected explicitly.
- Linux CI uses ubuntu-24.04 with the official `swift:6.3.2-noble` image.
- SwiftSyntax starts at stable 603.0.1 and remains in the 603 major line.
- Local Swift Testing command: `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`.

## Candidate validation

The two platform matrices independently run core, path consumer, exact candidate revision consumer, and legacy alpha.1 consumer suites. Independent jobs continue when another fails. Toolchain, resolver pins, and smoke logs are uploaded as artifacts.

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
scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1 --profile legacy-alpha1
scripts/template-smoke-test.sh --mode release --version 0.1.0-alpha.1
```

All source-control consumers record the resolved revision. Release consumers use exact versions. `--profile current` selects current API coverage independently of dependency source; `legacy-alpha1` is only for the first release's older API surface. Simply changing `--version` must not suppress new capability checks.

The current consumer includes macro dependencies, middleware, optional query/header HTTP behavior, an expected compile failure for optional path inputs, SwiftLog, ServiceLifecycle, HTTP Types, and OpenAPI transport. The OpenAPI example runs actual generated client/server code over HTTP. The template and commerce example are separately compiled as external packages.

## Ready for external trial

- Runtime and macro routing, middleware, keyed dependencies, typed inputs, JSON.
- One-shot request streams and demand-driven response streams, SSE, and bounded collection.
- Explicit OpenAPI schemas/security components and optional generated-server transport.
- Optional SwiftLog, ServiceLifecycle, and HTTP Types integrations.
- Lifecycle failure aggregation, all teardown hooks attempted once, and cancellation tests.
- In-memory testing, real-socket regression tests, and fixed application-change exercises.

## Known limits

- Public APIs are experimental; use the docs corresponding to your dependency version.
- HTTP/1.1 only; no built-in TLS, HTTP/2, request draining deadline, or upload deadlines.
- Cooperative cancellation cannot forcibly stop handler code that ignores cancellation.
- `body` and `bodyString` are buffered compatibility views; streams require bounded async helpers.
- OpenAPI validation covers the supported explicit schema subset, not the complete OpenAPI/JSON Schema standard.
- Mixed generated path templates such as `{name}.zip` are rejected.
- `@Security` is metadata only; applications own authentication middleware.
- Deep Swift schema derivation, keyless dependency inference, optional path segments, and managed `ApplicationService` runtime APIs remain deferred.
- ORM, queues, WebSocket, deployment tooling, and published benchmarks remain future work.

## Release gate

1. Finish and review all task slices; update AIDEV and the machine-readable registry.
2. Pass the full macOS/Linux matrix on the exact candidate commit.
3. Give the changelog a versioned section and state support/migration notes clearly.
4. Tag using semver prerelease form only after the candidate is validated.
5. Dispatch CI with `release_version` to run the identical current capability set against the exact published version, including commerce and generated OpenAPI examples.
6. Preserve old alpha.1 coverage independently; never infer new API validation from the legacy suite.
