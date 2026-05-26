# Project Map

## Root

```text
Daylily/
├── AIDEV.md
├── DAYLILY_NOTES.md
├── Package.swift
├── README.md
├── README.zh-CN.md
├── Sources/
│   ├── Daylily/
│   ├── DaylilyCore/
│   ├── DaylilyJSON/
│   ├── DaylilyMacros/
│   ├── DaylilyNIO/
│   └── HelloDaylily/
└── ai/
    ├── epics/
    ├── aidev/
    ├── prompts/
    └── tasks/
```

## Package Products and Targets

`Daylily`

- Public user-facing library.
- Re-exports `DaylilyCore`, `DaylilyJSON`, and `DaylilyNIO`.
- Adds `Application.run(host:port:)`.
- Exposes `@DaylilyServer`, `@GET`, `@POST`, and `@GROUP`.

`DaylilyCore`

- Framework runtime.
- Owns request, response, body, route, router, handler, status, headers, parameters, errors.
- Must stay independent from NIO and transport-specific APIs.

`DaylilyJSON`

- JSON convenience module.
- Depends on `DaylilyCore` and Foundation.
- Owns `request.json(...)` body decoding and `JSON(...)` response conversion.
- Keeps JSON/Foundation concerns out of `DaylilyCore`.

`DaylilyMacros`

- Internal macro target.
- Swift macro implementation target.
- Owns the compiler plugin for `@DaylilyServer`, `@GET`, `@POST`, and `@GROUP`.
- Must lower macro syntax into runtime APIs instead of bypassing them.

`DaylilyNIO`

- NIO-backed HTTP transport.
- Creates Daylily `Request` after NIO request head with a streaming `Body`.
- Feeds NIO body chunks into `BodyBytes` without exposing NIO types.
- Uses bounded buffering and practical backpressure for request bodies.
- Converts Daylily `Response` into NIO HTTP response parts.

`HelloDaylily`

- Example executable and current smoke-check host.
- Default `swift run` launches the HTTP server.
- `swift run HelloDaylily --check` runs in-process runtime checks.
- Includes `/upload/count` for chunked upload smoke checks.

## Source Files

`Sources/Daylily/Application+Run.swift`

- Extends `Application` with `run(host:port:)`.
- Bridges user-facing app runtime to `NIOHTTPServer`.

`Sources/Daylily/Exports.swift`

- Re-exports `DaylilyCore`, `DaylilyJSON`, and `DaylilyNIO`.

`Sources/Daylily/Macros.swift`

- Public macro declarations for `@DaylilyServer`, `@GET`, `@POST`, and `@GROUP`.

`Sources/DaylilyCore/Application.swift`

- Holds `Router`.
- Entrypoint for in-memory request handling via `respond(to:)`.
- Converts `ResponseError` failures into responses.

`Sources/DaylilyCore/Body.swift`

- Defines `Body`, `BodyBytes`, `ByteChunk`, `ByteCount`, and `BodyError`.
- Implements the 0008-001 one-shot body model.
- Buffered bodies yield one `ByteChunk`; streaming bodies yield transport-fed chunks.

`Sources/DaylilyCore/Errors.swift`

- Defines `ResponseError` and `Abort`.

`Sources/DaylilyCore/Handler.swift`

- Wraps route closures into one async response function.

`Sources/DaylilyCore/Headers.swift`

- Case-normalized header storage.

`Sources/DaylilyCore/HTTPMethod.swift`

- HTTP method enum.

`Sources/DaylilyCore/Parameters.swift`

- Path parameter container with dynamic member access.

`Sources/DaylilyCore/Request.swift`

- Method, path, headers, `Body`, parameters.

`Sources/DaylilyCore/Response.swift`

- Response model and `ResponseConvertible`.

`Sources/DaylilyCore/Route.swift`

- Route model.
- `Get`, `Post`, `Group` runtime DSL.

`Sources/DaylilyCore/RouteBuilder.swift`

- Result builder for route lists.

`Sources/DaylilyCore/Router.swift`

- Matches request method/path to a route.

`Sources/DaylilyCore/Status.swift`

- HTTP status model, including `413 Payload Too Large`.

`Sources/DaylilyJSON/JSON.swift`

- Defines the `JSON<Value>` response wrapper.
- Adds async `Body.json(_:upTo:)` and `Request.json(_:upTo:)` body decoding.
- Converts JSON decode failures into `Abort(.badRequest, reason: "Invalid JSON body")`.

`Sources/DaylilyMacros/DaylilyMacros.swift`

- Macro implementation and compiler plugin registration.
- `@DaylilyServer` scans route methods and group structs, then generates `static main() async throws`.
- `@GET`, `@POST`, and `@GROUP` are marker macros used by `@DaylilyServer`.

`Sources/DaylilyNIO/NIOHTTPServer.swift`

- NIO HTTP server and channel handler.

`Sources/HelloDaylily/HelloDaylily.swift`

- Default executable entry.

`Sources/HelloDaylily/Checks.swift`

- Lightweight checks used until a real test target is added.

`Sources/HelloDaylily/Payloads.swift`

- Shared DTOs for example JSON routes and checks.

`Sources/HelloDaylily/MacroSmoke.swift`

- Compile-time smoke coverage for macro route/group MVP.

## AI Files

`ai/tasks/`

- Task notes and implementation records.
- File names use `NNNN-XXX-short-kebab-name.md`.
- Tasks are the smallest commit/push unit.
- Steps are tracked inside task files, not as separate task files.

`ai/epics/`

- Theme-level planning containers.
- File names use `NNNN-short-kebab-name.md`.
- Epics are not direct implementation units.

`ai/aidev/`

- AI operating system for the project.

`ai/prompts/`

- Standard prompts for AI agents that take over Daylily work.

## AIDEV Files

`ai/aidev/start-here.md`

- First file for AI handoff.

`ai/aidev/concepts.md`

- Core concepts and mental model.

`ai/aidev/runtime-contracts.md`

- Runtime contracts by component.

`ai/aidev/invariants.md`

- Rules that must not be broken.

`ai/aidev/extension-playbooks.md`

- Step-by-step recipes for adding features.

`ai/aidev/task-protocol.md`

- Required task format and lifecycle.

`ai/prompts/daylily-agent.md`

- Standard agent prompt for future AI sessions.
