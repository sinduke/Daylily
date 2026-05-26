# 0020 Package Consumer Experience

Status: in-progress

Purpose:

- Make Daylily comfortable to consume as a third-party SwiftPM package.
- Validate the experience from a fresh external project, not only from inside the framework repository.
- Establish release gates that catch package identity, macro, testing, and dependency-resolution issues before tags.

Tasks:

- `0020-001-external-consumer-smoke-test` (implemented)
- `0020-002-minimal-app-template` (planned)
- `0020-003-first-real-api-example` (planned)
- `0020-004-dependency-injection-design` (planned)
- `0020-005-di-runtime-mvp` (planned)

Required work:

- External SwiftPM consumer smoke tests for local path and released package modes.
- Minimal user project shape after the smoke test proves package consumption.
- A small real API example before dependency injection is finalized.
- Dependency injection design grounded in the external project and example app shapes.

Non-goals:

- Replacing the existing repository quickstart.
- Claiming API stability before beta.
- Starting ORM, auth, queue, deployment, or broad ecosystem modules.
