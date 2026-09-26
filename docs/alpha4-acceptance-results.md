# Alpha.4 candidate acceptance — 2026-09-26

All six tasks in [epic 0026](../ai/epics/0026-real-business-and-sustained-operation.md), covering priorities P1–P5 and integration, are implemented and verified. Tested source: `1f8e0ea5f149b09cc398d302bf37c5cd63258452`. The later closure commit changes documentation/evidence only. The candidate remains unreleased; the latest published tag is alpha.3.

## Implemented scope

- Separate persistent commerce consumer with application-owned PostgreSQL pool, transactions, readiness, cancellation, migration and resource lifecycle; concurrent idempotent orders and restart persistence.
- Server-wide bounded observer delivery, saturation counters and per-write stall deadlines.
- Verified-TLS API/SSE/database deployment, dependency outage/recovery, rolling replacement and one hour of mixed traffic.
- Explicit nullable contracts, directional compatibility checks and real generated-client HTTP regressions.
- Three broader cross-file AI changes with withheld acceptance, first-pass/repair accounting and retained transcripts.

## Completed verification

[Full CI](https://github.com/sinduke/Daylily/actions/runs/36244501153) passed **12/12 jobs** on the exact source. Downloaded artifacts independently verify 12 current resolver pins and four legacy alpha.1 pins. Both persistent consumers retain their complete log/lock/dependency records. See [CI audit](../ai/evals/deployment/results/2026-09-26-alpha4/ci-audit.md).

| Check | Result |
| --- | --- |
| Swift core, each platform | 74 tests / 7 suites passed |
| Python compatibility, each platform | 35 methods passed |
| Real TCP harness regression, each platform | 13 tests passed |
| Generated-client contracts, both path and revision on both platforms | 10/10 HTTP groups per run |
| Persistent consumers, each platform | Executable build and 2 unit tests passed |
| Actual broader AI edits | 6/6 first-pass acceptance, zero repairs |
| CI AI baseline checks | 3/3 incomplete starters validated per platform, no model calls |
| Local real PostgreSQL/HTTP acceptance | 13 checks passed |
| Corrected Linux short deployment | 60.162 s, 3,214 successes, 20 expected 503s, zero unexpected failures |

The six actual AI trials use an immutable archive of published alpha.3, with version-matched documentation; they assess the broader edit fixtures, rather than claiming six model trials against alpha.4. [AI evidence](../ai/evals/repeated-changes/results/2026-09-26-alpha4/README.md) states the protocol and limitations. Local integration also passed the public consumer, original commerce, default server HTTP and SIGTERM checks.

Review found and fixed an idempotency/catalog race: the same deterministic two-server test returns 201/400/201 before the full-key transaction lock, and 201/201/201 with the original order after it. Initial CI exposed the missing Linux FoundationNetworking import, Python 3.12 response-reader bug and container artifact-path omission. These failed attempts are preserved in the [evidence index](../ai/evals/deployment/results/2026-09-26-alpha4/README.md).

## One-hour external Linux result

[Run 36244505313](https://github.com/sinduke/Daylily/actions/runs/36244505313) passed: **3600.175 seconds; 223,821 successful requests; 20 expected database 503s; zero unexpected failures; 494 resource records (493 complete samples and one planned restart gap); peak RSS 36,248 KiB; zero cleanup errors**. This is a clean Linux amd64 build at the exact candidate revision, using Swift 6.3.2. All 16 resolved dependency versions/revisions match the committed persistent lock file.

TLS rejected an untrusted root and incorrect hostname, then verified the trusted CA/hostname. SSE arrived incrementally and disconnect released the stream. Both replicas returned health 200 and readiness/business 503 during the injected database outage, then recovered without application restart with the order preserved. Concurrent same-key replays, distinct orders and conflicting payloads behaved correctly before and after faults.

During rolling replacement, the process drained in 2.164 seconds and SSE ended in 2.023 seconds; exit code was zero and all 16 proxy probes reached the surviving replica. Order state survived application and database restarts. Both replicas ended with zero active streams and at most one active request (the metrics request itself).

| Replica / generation | Samples | Peak RSS KiB | RSS median growth KiB | FD median growth | Idle FD delta across trial |
| --- | --- | --- | --- | --- | --- |
| a / 0 | 147 | 36,244 | +3,224 | -3 | +1 |
| a / 1 | 99 | 35,328 | +2,128 | +5 | +1 |
| b / 0 | 247 | 35,952 | +3,732 | +0 | +0 |

Every process generation meets the predeclared budgets: absolute RSS at most 512 MiB, window growth at most 64 MiB and FD growth at most 32. There are 494 timestamped resource records: 493 complete samples and one explicitly classified sampling gap while replica a was deliberately restarted. That partial record includes a valid RSS reading of 36,248 KiB, the maximum across all readings; the table uses complete per-generation samples. Unexpected resource sampling errors and cleanup errors are zero. Independent audit recomputed the raw data, source/harness/image provenance and TLS certificate hash; [retained results and artifact hashes](../ai/evals/deployment/results/2026-09-26-alpha4/README.md) support the figures.

This is paced mixed traffic on a private ephemeral GitHub-hosted topology, not a peak-capacity benchmark or persistent public endpoint. These resource windows do not prove leak freedom. A separate 24-hour soak is a later Beta gate; it is outside this completed alpha.4 checklist.
