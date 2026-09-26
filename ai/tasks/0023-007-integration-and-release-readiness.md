# 0023-007 Integration and Release Readiness

Status: in-progress
Epic: 0023-reliability-and-streaming

Goal:

- Integrate all five user-requested work streams and validate an exact release candidate.

Scope:

- Shared AIDEV/API/machine registry synchronization, capability and migration docs.
- Default streaming OpenAPI transport with explicit bounded compatibility policy.
- Task-level commits, remote main synchronization, and macOS/Linux candidate CI.

Non-goals:

- Publishing a new stable release or adding deferred ORM, managed services, or TLS/HTTP2.

Steps:

- [x] 0023-007.1 Review integrated runtime, examples, and consumer scripts.
- [x] 0023-007.2 Complete local build/test/check, real HTTP and external smoke validation.
- [x] 0023-007.3 Synchronize shared documentation and registry.
- [ ] 0023-007.4 Commit complete task slices and pass remote candidate CI.

Architecture impact:

- Existing optional boundaries are retained; OpenAPI response streaming reuses core ResponseBody.

Public API impact:

- OpenAPIResponseBodyPolicy.stream/collect(upTo:) and explicit buffering compatibility initializer.
- See the individual task records and api-registry for other task-owned additions.

AIDEV updates required:

- All architecture/API/feature maps, current support matrix, verification commands, and task status.

Validation:

- Full local suite and consumer/template/commerce/OpenAPI/application exercises.
- CI core/path/revision/legacy on macOS and Linux, with preserved resolver/log artifacts.
- 2026-09-26 local validation: Swift 6.3.2 build, all 49 package tests, and HelloDaylily checks passed. After the final channel-active guard, all 19 streaming tests passed again without stopped-event-loop scheduling warnings.
- Default HelloDaylily real HTTP smoke passed `/hello`, `/json/health`, and POST `/json/echo`; the process was stopped afterward.
- Current consumer (five tests plus macro compile-failure and HTTP checks), template, commerce, real generated OpenAPI client/server, and six application-change exercise tests passed. Legacy alpha.1 consumer/template passed separately; exact final candidate revision coverage is assigned to remote CI.
- Independent review found and fixed configure cancellation before boot and confirmed the final connection scheduling gate has no missing continuation completion paths.

Notes:

- 2026-09-26: Vapor 5 beta.1 (2026-09-15) and beta.2 (2026-09-16) confirm streaming/cancellation and packaging as immediate priorities. No dependency on Vapor is introduced.
- Individual implementation tasks may be marked implemented after local review/docs; this integration task remains in-progress until remote CI confirms the candidate.
