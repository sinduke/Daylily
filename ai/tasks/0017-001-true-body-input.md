# 0017-001 True Body Input

Status: implemented

Goal:

- Add the intended `@Body` typed JSON request body spelling for macro route handlers.
- Resolve the naming conflict with the existing raw request body type.
- Keep existing `@JSONBody` handlers working as a compatibility alias spelling.

Scope:

- Rename the raw request body type from `Body` to `RequestBody`.
- Keep the `request.body` property name unchanged.
- Add public `@Body` marker wrapper in `DaylilyJSON`.
- Keep public `@JSONBody` marker wrapper.
- Extend `@DaylilyServer` parameter lowering to accept `@Body`.
- Lower `@Body input: T` into `try await req.json(T.self)`.
- Lower `@Body` into `RouteBodyMetadata.json(...)`.
- Add macro smoke coverage for top-level and grouped `@Body`.
- Update behavior checks, formal tests, README, AIDEV docs, and registry.

Non-goals:

- Raw body macro injection.
- Optional body inputs.
- Content-type enforcement.
- Multiple request bodies per handler.
- Changing request body one-shot semantics.
- Changing JSON decoding limits.

Rules:

- `Request.body` remains a one-shot Daylily-owned body stream.
- The raw body type is `RequestBody`.
- `Body` is reserved for macro typed JSON body input sugar.
- `@JSONBody` remains supported as a compatibility alias spelling.
- A handler may have at most one `@Body` or `@JSONBody` parameter.
- `@Body` and `@JSONBody` both use `Request.json(_:upTo:)`.
- `@Body` and `@JSONBody` both lower into the same runtime route metadata model.

Target usage:

```swift
@POST("/users")
func create(@Body input: CreateUserInput) async throws -> JSON<UserResponse> {
    JSON(UserResponse(id: input.id))
}
```

Raw body usage:

```swift
let body = RequestBody.bytes(Array("hello".utf8))
let text = try await request.body.string(upTo: .kilobytes(64))
```

Steps:

- [x] 0017-001.1 Rename raw `Body` type to `RequestBody`.
- [x] 0017-001.2 Add public `@Body` marker while keeping `@JSONBody`.
- [x] 0017-001.3 Extend macro lowering and diagnostics.
- [x] 0017-001.4 Add macro smoke and check coverage.
- [x] 0017-001.5 Update README and AIDEV docs.
- [x] 0017-001.6 Review, fix, validate, then finish the task.

Validation:

Required after implementation:

```sh
swift build
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test
swift run HelloDaylily --check
```

Completed validation:

- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`
