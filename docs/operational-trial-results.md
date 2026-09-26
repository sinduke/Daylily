# Operational acceptance — 2026-09-26

## Release

[Alpha.2](https://github.com/sinduke/Daylily/releases/tag/0.1.0-alpha.2) was published at `f0d53421981e42e423e0b53b4f6a5dc3460bec81` after its eight-job preparation gate. [Exact-tag validation](https://github.com/sinduke/Daylily/actions/runs/36212096436) passed all ten macOS/Linux jobs; downloaded package records confirm the version and revision. The operational runtime below is a subsequent, unreleased increment.

## Local runtime

Swift 6.3.2 / Xcode 26.5 passed `swift build`, 65 tests across six suites, and `HelloDaylily --check`. The default `swift run --skip-build` served the documented hello/JSON routes and exited cleanly on SIGTERM. The focused 35-test stream/operation/observer run includes stalled input, disabled deadlines, backpressure, early SSE, quiescing, forced cancellation and observer isolation.

Independent review corrected two deadline boundaries before the final tests: an early response must abandon its upload timer, and the next header timer starts after response-end flush. No stopped-event-loop scheduling warnings appeared in the focused run or container logs.

## Linux container deployment

[Committed evidence](../ai/evals/deployment/results/2026-09-26/README.md) preserves the original results and reproducibility metadata. Environment: Docker 29.4.0, Linux arm64 containers under the local macOS host, Swift 6.3.2 release build, two application replicas, and digest-pinned Caddy. The source snapshot was based on `f0d5342` with uncommitted operational changes, not the published tag itself.

| Observation | Measured result |
| --- | --- |
| Sustained phase | 300.073 seconds, 4 workers |
| Successful requests | 31,382 |
| Request failures | 0 |
| Mixed-request latency | p50 3.86 ms; p95 48.22 ms |
| SSE event arrival | 7 events; first 1.09 ms; last 3.03 seconds |
| Partial-head timeout | 2.004 seconds |
| Stalled-upload timeout | 2.010 seconds |
| Rolling drain | 2.256 seconds, short request completed, long SSE stopped |
| Slow reader | 14,353,053 aggregate observed body bytes before cancellation, below the 256 MiB source |
| Client disconnect / producer error | Cancellation released its live producer; post-header error observed |
| End-of-load active streams | 0 on both replicas |
| Resource cleanup | No errors; only trial resources removed |

The latency distribution mixes health, JSON and SSE requests; SSE deliberately includes delays. Slow-reader byte accounting includes nearby health/metrics responses. These figures describe this paced local trial, not maximum throughput. Snapshot memory readings do not establish leak freedom. The trial has no public endpoint, TLS, database, authentication or persistent job state, and was not an overnight soak.

## Contract and actual AI edits

The conservative compatibility checker passes 29 tests, including response-default fallback and unsupported range statuses. Three actual generated modules verify old/new clients against compatible and breaking servers over localhost HTTP. Six model-edit trials (three tasks × two starts) passed immutable acceptance, without model retries or copied reference implementations. All three incomplete baselines fail as intended.

[AI trial evidence](../ai/evals/repeated-changes/results/2026-09-26/README.md) records patches, events, model time (35.6–44.8 seconds per trial), acceptance and token fields. Total parallel runner time was 177.072 seconds; monetary cost is unknown. These open-test examples support only the fixed tasks, not a general model success rate.

## Final candidate CI

Candidate `3bad369331e05231a0c644f148cb59be5f7dc898` passed [final CI validation](https://github.com/sinduke/Daylily/actions/runs/36212918755): macOS/Linux core/path/revision/legacy jobs plus a separate Linux Docker deployment job. **All nine jobs passed.** Downloaded revision artifacts on both platforms verify that all five external consumers (consumer, template, commerce, OpenAPI and contract regression) resolved this exact commit. Both contract logs confirm all four real HTTP scenarios passed. Final follow-up commits update documentation only; the validated runtime and CI configuration remain unchanged.

Completed core logs on both platforms confirm 65 Swift tests, 29 compatibility tests and behavior checks. The clean-checkout Linux amd64 Docker job passed 30.023 seconds of sustained traffic: 3,940 successes, zero failures, 2.100-second rolling drain, zero active streams afterward and no cleanup errors. Its artifact records the exact candidate SHA and `working_tree_dirty: false`; this independently verifies the later explicit base-image pull on a fresh CI host.
