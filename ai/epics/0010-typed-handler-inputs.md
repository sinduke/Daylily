# 0010 Typed Handler Inputs

Status: implemented

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
func create(@JSONBody input: CreateUserInput) async throws -> Status {
    ...
}
```

Recommended tasks:

- `0010-001-typed-path-extraction-runtime` (implemented)
- `0010-002-path-macro-mvp` (implemented)
- `0010-003-body-json-macro-runtime-bridge` (implemented)
- `0010-004-query-and-header-inputs` (implemented)

Order:

1. Runtime typed path extraction.
2. `@Path` macro MVP.
3. Minimal `DaylilyTesting` before larger handler input expansion.
4. `@JSONBody` JSON macro bridge.
5. `@Query` and `@Header`.

Design notes:

- `0010-001` delivered the runtime API: `ParameterDecodable`, `Parameters.require(_:as:)`, `Parameters.get(_:as:)`, and `ParameterError`.
- `0010-002` delivered macro `@Path` input injection by lowering into `Parameters.require(_:as:)`.
- `0010-003` delivered macro `@JSONBody` input injection by lowering into `Request.json(_:upTo:)`.
- `0010-004` delivered typed query/header extraction and macro `@Query` / `@Header` input injection.
- True `@Body` spelling is deferred because `Body` is already Daylily's raw request body type.
- `DaylilyCore` should stay small.
- Foundation-backed types such as `UUID` need a deliberate decision before being added to core.
- Missing or invalid path parameters should map to `400 Bad Request`, not `500`.
- Error reasons should be clear enough for AI agents to diagnose quickly.

Non-goals for the first task:

- Full parameter injection macros.
- Query/header/cookie extraction.
- True `@Body` spelling.
- OpenAPI metadata.
- Validation framework.
