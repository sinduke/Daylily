# 0010 Typed Handler Inputs

Status: in-progress

Purpose:

- Move Daylily from raw request access toward typed handler inputs.
- Make handler signatures feel declarative and distinct from Vapor/Hummingbird style.
- Keep runtime APIs as the source of truth before macro sugar.

Target experience:

```swift
@GET("/users/:id")
func user(@Path id: UUID) async throws -> JSON<User> {
    ...
}

@POST("/users")
func create(@Body input: CreateUserInput) async throws -> Status {
    ...
}
```

Recommended tasks:

- `0010-001-typed-path-extraction-runtime` (implemented)
- `0010-002-path-macro-mvp`
- `0010-003-body-json-macro-runtime-bridge`
- `0010-004-query-and-header-inputs`

Order:

1. Runtime typed path extraction.
2. `@Path` macro MVP.
3. Minimal `DaylilyTesting` before larger handler input expansion.
4. `@Body` JSON.
5. `@Query` and `@Header`.

Design notes:

- `0010-001` delivered the runtime API: `ParameterDecodable`, `Parameters.require(_:as:)`, `Parameters.get(_:as:)`, and `ParameterError`.
- First runtime step should avoid query/header/body scope creep.
- `DaylilyCore` should stay small.
- Foundation-backed types such as `UUID` need a deliberate decision before being added to core.
- Missing or invalid path parameters should map to `400 Bad Request`, not `500`.
- Error reasons should be clear enough for AI agents to diagnose quickly.

Non-goals for the first task:

- Full parameter injection macros.
- Query/header/cookie extraction.
- JSON body macro.
- OpenAPI metadata.
- Validation framework.
