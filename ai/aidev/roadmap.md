# Roadmap

Daylily now uses an Epic / Task / Step planning model.

```text
Epic -> Task -> Step
```

- Epics live in `ai/epics/`.
- Tasks live in `ai/tasks/`.
- Steps live inside task files as checklists.
- Tasks are the smallest commit/push unit.

## Completed Epics

### 0001 Runtime Foundation

Status: implemented

Tasks:

- `0001-001-minimal-http-server`

Delivered:

- Swift package skeleton.
- Runtime route DSL.
- `Application.respond(to:)`.
- NIO HTTP transport.
- Default `swift run` server.
- `swift run HelloDaylily --check` behavior checks.
- Basic `Get`, `Post`, and `Group`.
- Path parameter matching.
- 404 behavior.

### 0002 AIDEV System

Status: implemented

Tasks:

- `0002-001-aidev-project-contract`
- `0002-002-aidev-self-contained-spec`
- `0002-003-bilingual-readme-ai-native`
- `0002-004-work-model-reorganization`
- `0002-005-github-actions-node24`

Delivered:

- Project map and architecture boundaries.
- Self-contained AI handoff docs.
- Workflow, task protocol, extension playbooks, and registry.
- Epic / Task / Step work model.
- GitHub Actions checkout action updated for Node.js 24.
- English and Simplified Chinese README files.
- AI-native development model documentation.

### 0003 Routing Macro System

Status: implemented

Tasks:

- `0003-001-macro-route-mvp`
- `0003-002-group-macro-mvp`

Delivered:

- `@DaylilyServer`
- `@GET`
- `@POST`
- `@GROUP`
- Macro lowering into runtime route DSL.

### 0004 JSON System

Status: implemented

Tasks:

- `0004-001-json-body-and-response`

Delivered:

- `DaylilyJSON` module.
- `request.body.json(Type.self, upTo:)`.
- `request.json(Type.self)` convenience sugar.
- `JSON(value)` response wrapper.
- `content-type: application/json` response header.
- Example JSON routes and behavior checks.

### 0008 Body System

Status: implemented

Tasks:

- `0008-001-body-model-migration`
- `0008-002-nio-true-streaming-bridge`

Delivered:

- `Request.body: Body`.
- One-shot body consumption.
- `BodyBytes` with `ByteChunk`.
- `ByteCount` units for bytes, kilobytes, megabytes, and gigabytes.
- Async JSON body decoding.
- 413 `Payload Too Large` body limit mapping.
- NIO true streaming body bridge.
- Bounded buffering and practical NIO `autoRead` backpressure.
- Chunked upload smoke route.

## Recommended Next Epic

### 0009 Middleware System

Status: proposed

Likely first task:

- `0009-001-middleware-runtime`

Goal:

- Add middleware pipeline and group/route scoping.
- Define ordering, short-circuiting, and error behavior.
- Build runtime support before macro sugar.

## Later

### 0010 Typed Parameter Extraction

Status: proposed

Likely first task:

- `0010-001-typed-parameter-extraction`

Example target:

```swift
func user(@Path id: UUID) async throws -> User
```

### Future Epics

- OpenAPI metadata.
- Dependency injection.
- Request context.
- Production server controls.
