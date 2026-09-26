# Recorded run — 2026-09-26

The three reference implementations were completed using the repository's AIDEV
runtime, dependency, JSON, testing, and explicit OpenAPI schema contracts.

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer scripts/ai-exercises-smoke-test.sh --mode path --keep
```

Environment: macOS arm64, Apple Swift 6.3.2, Xcode 26.5, a fresh external consumer
resolving the current Daylily working tree.

| Concrete task | Observed result |
| --- | --- |
| Add a greeting endpoint and keep health | 2 acceptance tests passed |
| Select a replacement provider through a typed protocol key | 2 acceptance tests passed |
| Add required author to input/output DTOs and explicit schemas | 2 acceptance tests passed |

Swift Testing reported **6 tests in 3 suites passed**. The consumer's retained
`dependency-record.json` records the source checkout, base revision, and whether
working tree changes were included. The CI smoke emits the same record for later
runs; CI artifacts are the source for exact revision provenance.

This run validates these three concrete implementations. There was no blinded
evaluation, repeated model trial, latency/cost measurement, or general success-rate
estimate. Checks use the in-memory `TestClient`; the independent OpenAPI service
example covers generator output and network transport.
