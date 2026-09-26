# 0024-004 Deployment Trial

Status: implemented
Epic: 0024-release-and-operational-readiness

Goal:

- Exercise the operational runtime through a real Linux container reverse-proxy deployment.

Scope:

- Independent API/SSE trial app, two replicas, Caddy, bounded slow-reader and disconnect checks, rolling replacement, sustained requests, and reproducible evidence.

Non-goals:

- Public cloud deployment, paid infrastructure, durable job state, production capacity certification, native TLS/HTTP2, or an overnight soak claim.

Steps:

- [x] 0024-004.1 Build an independent API/SSE app using operation deadlines and transfer observation.
- [x] 0024-004.2 Run replicas and a reverse proxy with scoped resource cleanup.
- [x] 0024-004.3 Verify incremental events, stalled peers, cancellation, and rolling replacement.
- [x] 0024-004.4 Run a measured sustained traffic trial and record duration, results, images, and limits.

Architecture impact:

- The app and container harness are external consumers; no proxy/container dependency enters the framework.

Public API impact:

- Consumes 0024-002/003 APIs without adding framework API.

AIDEV updates required:

- New command/example, deployment guide, project map, validation and registry.

Validation:

- Real Docker bridge network, HTTP requests through Caddy, backend observations and shutdown logs, plus JSON trial results.

Notes:

- Uses local Linux containers and loopback-only host ports; each run removes only its own named containers/network/image.

Integration evidence:

- Shared AIDEV API/runtime/map/registry and user guides are synchronized. Local full build, 65 tests and behavior checks passed; default server HTTP/SIGTERM passed.
- The 300-second Linux/Caddy deployment passed 31,382 requests with no failures and clean teardown. See `docs/operational-trial-results.md`.
- Exact-candidate cross-platform CI is tracked separately by 0024-006; this task status records implemented and locally validated scope.
