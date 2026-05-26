# 0020 Package Consumer Experience

Status: in-progress

Purpose:

- Make Daylily comfortable to consume as a third-party SwiftPM package.
- Validate the experience from a fresh external project, not only from inside the framework repository.
- Establish release gates that catch package identity, macro, testing, and dependency-resolution issues before tags.

Tasks:

- `0020-001-external-consumer-smoke-test` (implemented)
- `0020-002-minimal-app-template` (implemented)
- `0020-003-first-real-api-example` (implemented)
- `0020-004-dependency-injection-design` (implemented)
- `0020-005-dependencies-registry-mvp` (planned)
- `0020-006-di-usage-polish` (planned)
- `0020-007-protocol-keyed-dependencies-design` (planned)
- `0020-008-lifecycle-integration-design` (planned)
- `0020-009-macro-dependency` (planned)

Required work:

- External SwiftPM consumer smoke tests for local path and released package modes.
- Minimal user project shape after the smoke test proves package consumption.
- A small real API example before dependency injection runtime implementation.
- Dependency injection design grounded in the external project and example app shapes.
- A small `Dependencies` registry MVP before protocol, keyed, lifecycle, or macro injection work.

Dependency sequence:

```text
0020-004 Dependency Injection Design
0020-005 Dependencies Registry MVP
0020-006 DI Usage Polish
0020-007 Protocol / Keyed Dependencies Design
0020-008 Lifecycle Integration Design
0020-009 Macro @Dependency
```

Non-goals:

- Replacing the existing repository quickstart.
- Claiming API stability before beta.
- Starting with macro syntax before runtime behavior exists.
- Combining protocol lookup, keyed dependencies, lifecycle, and macros into the first DI slice.
- Starting ORM, auth, queue, deployment, or broad ecosystem modules.
