# 0023-005 Lifecycle Failure Recovery

Status: implemented
Epic: 0023-reliability-and-streaming

Goal:

- Run teardown once, attempt every teardown hook, and preserve startup and teardown failures.

Scope:

- Share one runtime execution path between Application.run and the optional ServiceLifecycle adapter.
- Configure failure runs cleanup; boot, bind, started, and serving failure run shutdown followed by cleanup.
- Teardown proceeds in an awaited task independent of parent cancellation.

Non-goals:

- Managed ApplicationService registration and implicit resource discovery.

Steps:

- [x] 0023-005.1 Implement shared lifecycle runner and aggregate errors.
- [x] 0023-005.2 Exercise failures and cancellation across both entry points.
- [x] 0023-005.3 Update runtime contracts and validation records.

Architecture impact:

- Runtime owns lifecycle execution; transport startup is supplied through an SPI closure.

Public API impact:

- LifecycleFailure and LifecycleRunError preserve hook location and original errors.
- Shutdown and cleanup phases attempt every registered hook, in registration order.

AIDEV updates required:

- API registry, runtime contracts, machine registry, changelog, release readiness.

Validation:

- Focused lifecycle tests, full swift test, build, behavior checks, and consumer integration.

Integration note: implementation, shared documentation, and exact-candidate validation are complete. Task 0023-007 records all eight passing macOS/Linux CI jobs at candidate `7d56798`.

Validation: six lifecycle tests passed locally, including cancellation during configure, teardown failure aggregation, and both server entry points. Full suite and independent code review completed on 2026-09-26.
