# 0026-003 Sustained Linux Deployment

Status: in-progress
Epic: 0026-real-business-and-sustained-operation

Goal:

- A reproducible one-hour API/SSE/database deployment on external Linux with time-series resources and deliberate failures.

Scope:

- New `scripts/sustained-deployment-trial.py`: two persistent commerce replicas, Postgres 17 volume and pinned Caddy in a uniquely named private Docker network; only loopback host port mappings.
- Caddy `tls internal` for localhost; export the public CA certificate and verify both trust and hostname with Python's default SSL policy. Untrusted root and incorrect hostname are rejected.
- Concurrent distinct/idempotent orders, incremental/disconnected SSE, paced mixed requests, scheduled database stop/start and graceful replica replacement.
- Independent RSS/thread/FD/TCP/metrics sampling every 15 seconds (5 seconds for short runs), per-process generation attribution and explicit planned restart gaps.
- Predeclared budgets: RSS at most 512 MiB; each process generation's first/last three-sample median growth at most 64 MiB; FD median growth within +32 both per generation and across the idle baseline/final windows. These are operational budgets, not a leak proof.
- Exact checkout revision, dirty flag, captured Docker build-tree hash, image source labels/IDs/digests/architectures, actual Package.resolved, TLS certificate metadata and JSONL evidence.
- Best-effort collection of all owned logs followed by scoped cleanup; cleanup or unexpected request/sampling errors make the run fail.

Non-goals:

- A new published version tag, paid infrastructure, or a claim of production certification.

Steps:

- [x] 0026-003.1 Build the private reverse-proxy and persistent commerce topology with isolated resources.
- [x] 0026-003.2 Verify TLS/proxy behavior, API/SSE, process replacement and database outage/recovery.
- [ ] 0026-003.3 Collect timestamped RSS/FD/connection/request/stream data during at least 3,600 seconds of traffic.
- [ ] 0026-003.4 Run short local validation then the one-hour exact-candidate GitHub Linux trial and review artifacts.

Architecture impact:

- The deployment harness, workflow and example composition are external consumers; no container or database dependency enters core.

Public API impact:

- None directly; integrated API changes are documented by their owning tasks.

AIDEV updates required:

- Workflow, project map, roadmap, registry and relevant user-facing validation guides.

Validation:

- `python3 -m py_compile scripts/sustained-deployment-trial.py` passed. Focused fault-window checks confirm only product/order GET 503 responses overlapping the injected outage are classified as expected; health/SSE or outside-window failures are not excused. Invalid duration 59 exits 2 before creating evidence or Docker resources.
- Short local command: `python3 scripts/sustained-deployment-trial.py --duration 60 --artifacts /tmp/daylily-alpha4-sustained-smoke-2` exited 0. Measured sustained traffic: 60.053 seconds, 2,724 successes, 20 expected database 503 responses, zero unexpected failures. Both replicas returned health 200 and ready/business 503 during outage, then recovered automatically with the order preserved.
- Incremental SSE arrivals were 0.003/0.162/0.315 seconds; disconnect released its stream. Replica a drained for 2.223 seconds and exited 0; all 16 proxy probes reached b. Orders persisted across both database and application restarts; 16 same-key replays and 16 distinct concurrent orders passed before and after faults.
- Initial short trial collected 36 resource samples with approximately 31 MiB maximum RSS, no sampling errors, FD median growth +3/+0, idle streams zero and no cleanup errors. Evidence: `/tmp/daylily-alpha4-sustained-smoke-2/results.json` and sibling logs/JSONL. Its source snapshot predates the subsequent P1 idempotency transaction-lock correction; final source must be rebuilt and revalidated.
- Initial smoke-1 was deliberately interrupted before topology creation because an unnecessary pull of an already cached Swift image stalled for 85.96 seconds. Original failed evidence is retained; the old error string was empty because `str(KeyboardInterrupt())` is empty. The harness now records exception type and uses an existing local image when available, recording actual digests and acquisition source; fresh CI still pulls missing images.
- Final P1 transaction-lock source was rebuilt for smoke-3, which passed. Smoke-4 then used the same image ID under an independently owned diagnostic tag and verified its source labels/hash: `python3 scripts/sustained-deployment-trial.py --duration 60 --artifacts /tmp/daylily-alpha4-sustained-smoke-4 --skip-build daylily-alpha4-final-harness:trial` exited 0. Measured 60.051 seconds, 2,715 successful requests, 20 expected database 503s, zero unexpected failures. Process exit and SSE end were independently measured at 2.229 and 2.061 seconds; all 16 concurrent TLS proxy probes used replica b. Both idle and per-generation resource budgets passed across 36 samples; peak RSS 32,632 KiB, ending FD delta +1/+0, no cleanup errors.
- Smoke-4 executed harness SHA-256 `7a8d797c21e65ed015d684b3135d2cff9e8daae34c27fb7bec62f8d96d7cf2a6`. The final harness SHA-256 `f297249d501e79e1d7ba65b17e22167756109c1540720cd9f060f0d9c26032db` adds only the post-`read1` deadline assertion identified by independent review; a forced-EOF counterexample now raises TimeoutError. The exact final source will also run in CI short and one-hour jobs.
- Independent review caught and closed three evidence risks: FD growth hidden by a replica restart (now budgeted by generation), indefinitely writing responses or trickled headers preventing cleanup (now wall-clock socket watchdog, bounded chunk reads and 256 KiB response cap), and proxy probe latency inflating drain time (now independent concurrent process/stream timing).
- True TCP adversarial checks passed: endless body and trickled headers stop at approximately 0.20 seconds; oversized bodies are rejected immediately; sockets and deadline threads are released. A synthetic per-generation +698 FD growth counterexample now fails, and timeout-induced EOF is rejected for both normal responses and preflight SSE.
- Final-hash smoke-5 also passed: 60.100 seconds, 2,685 successes, 20 expected database 503s, zero unexpected failures; `image_source_verified=true`, executed harness hash exactly equals the frozen final file, all operational/resource gates and cleanup passed. Evidence: `/tmp/daylily-alpha4-sustained-smoke-5/results.json`. The separately tagged borrowed image was then explicitly removed with exit 0; `/tmp/daylily-alpha4-sustained-smoke-5/diagnostic-image-cleanup.json` records that final cleanup. No local trial resources remain and no further local trial is planned. Measured >= 3,600-second GitHub Linux validation remains pending. The parent owns CI execution and final evidence review.

Notes:

- Status remains in-progress until evidence is available. Twenty-four-hour soak is a later Beta gate.

Reproduction:

```sh
python3 scripts/sustained-deployment-trial.py --duration 60 --artifacts /tmp/daylily-short-new
python3 scripts/sustained-deployment-trial.py --duration 3600 --artifacts /tmp/daylily-hour-new
```

`--skip-build IMAGE` is available for local diagnosis; an unlabelled external image is explicitly not source-verified. Use the normal captured-source build for final exact-candidate evidence. Artifact directories must be new or empty. Generated database passwords remain in process/container environments, are not passed as command arguments, and are redacted from retained logs. Only the public CA certificate is exported.

Proxy semantics were checked against the official [reverse_proxy documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy) and [TLS documentation](https://caddyserver.com/docs/caddyfile/directives/tls): GET retry budget is five seconds, health checks use process liveness, and default SSE immediate flushing preserves disconnect cancellation. The negative `flush_interval` setting is deliberately absent because it changes upstream cancellation behavior.
