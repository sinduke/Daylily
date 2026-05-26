# 0010-003 Body JSON Macro Runtime Bridge

Status: implemented
Epic: 0010-typed-handler-inputs

Goal:

- Add the next typed handler input after `@Path`.
- Let macro handlers receive decoded JSON request bodies without manually touching `Request`.
- Keep runtime JSON decoding as the source of truth.

Scope:

- Add public `@JSONBody` marker.
- Extend `@DaylilyServer` parameter lowering to support `@JSONBody`.
- Lower `@JSONBody input: T` into `try await req.json(T.self)`.
- Allow one `@JSONBody` parameter per handler.
- Allow `Request` plus `@JSONBody` in the same handler.
- Add macro smoke coverage for top-level and grouped routes.
- Update AIDEV documentation, README examples, roadmap, and registry.

Non-goals:

- True `@Body` spelling.
- Configurable body limits in the marker.
- Content-type enforcement.
- Validation framework.
- Multipart or form decoding.
- Streaming body injection.
- OpenAPI metadata.

Target usage:

```swift
@POST("/users")
func create(@JSONBody input: CreateUserInput) async throws -> JSON<UserResponse> {
    ...
}
```

Target lowering:

```swift
Post("/users") { req in
    try await server.create(input: try await req.json(CreateUserInput.self))
}
```

Naming decision:

- The intended long-term user-facing spelling is still `@Body`.
- Swift parameter attributes currently need a property-wrapper-style declaration for this use.
- Daylily already has a public raw request `Body` type.
- Reusing the literal `Body` name for a generic property-wrapper marker would collide with the raw request body API and make `Body.bytes(...)` ambiguous or unusable for users importing `Daylily`.
- Attached peer macros also cannot be attached to function parameters.
- The MVP therefore ships `@JSONBody` as the clear JSON-specific marker and records true `@Body` as a future naming/design decision.

Rules:

- `@JSONBody` lives in `DaylilyJSON`.
- `@JSONBody` is a marker; actual decoding remains `Request.json(_:upTo:)`.
- The default body limit is the existing `request.json(...)` default of 1 MB.
- Invalid JSON still maps to `400 Bad Request` with reason `Invalid JSON body`.
- A handler may contain at most one `@JSONBody` parameter.
- Request bodies remain one-shot.

Steps:

- [x] 0010-003.1 Add public `@JSONBody` marker.
- [x] 0010-003.2 Extend macro parameter parsing for `@JSONBody`.
- [x] 0010-003.3 Generate `try await req.json(Type.self)` lowering.
- [x] 0010-003.4 Add macro smoke coverage.
- [x] 0010-003.5 Update README and AIDEV docs.
- [x] 0010-003.6 Review, fix, validate, then finish the task.

Architecture impact:

- Keeps JSON-specific typed input in `DaylilyJSON`.
- Keeps `DaylilyCore` free of JSON-specific marker APIs.
- Expands macro lowering without changing runtime request/body behavior.

Public API impact:

- Adds `JSONBody<Value: Decodable & Sendable>` property-wrapper marker in `DaylilyJSON`.
- Extends `@DaylilyServer` handler parameter support from `Request` and `@Path` to `Request`, `@Path`, and `@JSONBody`.

AIDEV updates required:

- `README.md`
- `README.zh-CN.md`
- `ai/aidev/start-here.md`
- `ai/aidev/project-map.md`
- `ai/aidev/architecture.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/concepts.md`
- `ai/aidev/conventions.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `ai/epics/0010-typed-handler-inputs.md`

Validation:

Required after implementation:

```sh
swift build
swift run HelloDaylily --check
```

Completed validation:

```sh
swift build
swift run HelloDaylily --check
swift build -Xswiftc -Xfrontend -Xswiftc -dump-macro-expansions 2>&1 | rg -n 'jsonEcho|req\.json\(MacroEchoPayload\.self\)|JSONBody'
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
```

Suggested checks:

- `@JSONBody input: T` compiles.
- `@JSONBody` works inside `@GROUP`.
- Macro expansion lowers to `req.json(T.self)`.
- Existing `Request` and `@Path` macro handler shapes still compile.
- `registry.yml` parses.
- `git diff --check` passes.

Notes:

- This task deliberately chooses a compilable marker name over pretending `@Body` is available. The future `@Body` design should be handled explicitly if Daylily renames or aliases the raw request body model.
