# 0026 Real Business and Sustained Operation

Status: in-progress

Goal:

Deliver the alpha.4 candidate through a real persistent business consumer, bounded transport resources, a one-hour external Linux deployment, concrete nullable contract support, and broader real AI edits. The user authorized the full checklist and requires completed verification before closure.

Delivery checklist:

- [x] 0026-001 Persistent commerce application: database integration, resource lifecycle, restart/concurrency/failure/recovery checks.
- [x] 0026-002 Runtime resource bounds: bounded transfer observation and outbound write-stall deadline, saturation/recovery tests.
- [ ] 0026-003 Sustained Linux deployment: reverse proxy, API/SSE/database, rolling replacement and dependency faults; at least 3,600 seconds of sustained traffic with resource time series.
- [x] 0026-004 Nullable contracts: explicit null versus absent semantics, compatibility direction and real generated-client HTTP regression.
- [x] 0026-005 Broader AI edits: cross-file business change, persistence and fault repair; withheld acceptance, first-pass/repair/time/token evidence.
- [ ] 0026-006 Integration and candidate validation: shared AIDEV/docs/registry, macOS/Linux core and exact-revision external consumers, evidence review.

Execution:

Business, runtime and contracts have separate owners and may run concurrently. The parent owns deployment, AI evaluations, shared documentation and final integration. Agents do not commit or modify shared AIDEV. Changes are committed at task granularity after review; the integrated candidate is pushed for exact-revision CI. GitHub-hosted Linux is the available external Linux deployment environment; its private ephemeral deployment is not a persistent public service. A 24-hour soak remains a later Beta admission gate, while this alpha.4 candidate requires a measured one-hour run. Publishing a new version tag is outside this implementation checklist.

Validation rules:

Do not infer validation from code presence. Record actual command exits, source revisions, measured durations and resolver pins. Keep prior published tags/evidence unchanged. Real model trials use the existing configured account and remain outside automatic CI. Failed attempts remain in evidence. No paid infrastructure is provisioned.
