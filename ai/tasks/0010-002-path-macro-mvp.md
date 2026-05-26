# 0010-002 Path Macro MVP

Status: implemented
Epic: 0010-typed-handler-inputs

Goal:

- Add the first macro-level typed handler input.
- Let `@DaylilyServer` lower `@Path` handler parameters into runtime `Parameters.require(_:as:)` calls.
- Keep runtime extraction as the source of truth.

Scope:

- Add a public `@Path` parameter marker.
- Extend route macro collection to support handler parameters annotated with `@Path`.
- Default the path parameter name to the Swift local parameter name.
- Support explicit mapping with `@Path("routeName")`.
- Support standard `ParameterDecodable` types through the runtime API.
- Validate that `@Path` names exist in the route path.
- Add macro smoke coverage.
- Update AIDEV documentation, README examples, and registry.

Non-goals:

- `@Body`
- `@Query`
- `@Header`
- Optional path values.
- `UUID` support.
- OpenAPI metadata.
- Dependency injection.
- Macro middleware attributes.

Target usage:

```swift
@DaylilyServer
struct Demo {
    @GET("/users/:id")
    func user(@Path id: Int) -> String {
        "User \(id)"
    }

    @GET("/accounts/:id")
    func account(@Path("id") accountID: Int) -> String {
        "Account \(accountID)"
    }
}
```

Target lowering:

```swift
Get("/users/:id") { req in
    server.user(id: try req.parameters.require("id", as: Int.self))
}
```

Rules:

- `@Path` is a marker for the macro layer.
- The actual extraction behavior stays in `Parameters.require(_:as:)`.
- Missing or invalid values still map through `ParameterError` as `400 Bad Request`.
- A `@Path` parameter must match a `:name` segment in the full route path, including group prefixes.
- `Request` parameters remain supported.

Steps:

- [x] 0010-002.1 Add public `@Path` marker API.
- [x] 0010-002.2 Extend macro parameter parsing for `@Path`.
- [x] 0010-002.3 Generate runtime `Parameters.require(_:as:)` calls.
- [x] 0010-002.4 Validate route-path membership for path inputs.
- [x] 0010-002.5 Add macro smoke coverage.
- [x] 0010-002.6 Update AIDEV docs, README examples, roadmap, and registry.
- [x] 0010-002.7 Review, fix, validate, then finish the task.

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
swift build -Xswiftc -Xfrontend -Xswiftc -dump-macro-expansions 2>&1 | rg -n 'typedUser|account\(|requestUser|parameters\.require'
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
```

Suggested checks:

- `@Path id: Int` compiles.
- `@Path("id") userID: Int` compiles.
- `@Path` works inside `@GROUP`.
- Existing `Request` parameter macro handlers still compile.
- `registry.yml` parses.
- `git diff --check` passes.

Notes:

- This is the first visible Daylily typed handler input.
- Keep it small. The next extraction families belong in later tasks.
