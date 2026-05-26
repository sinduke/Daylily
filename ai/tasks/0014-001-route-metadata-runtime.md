# 0014-001 Route Metadata Runtime

Status: implemented
Epic: 0014-openapi-metadata

Goal:

- Add runtime-owned route metadata before generating OpenAPI documents.
- Let routes describe inputs, request bodies, responses, tags, and summaries without source-code guessing.
- Make the runtime route model the source of truth for later OpenAPI and macro metadata work.

Scope:

- Add `RouteMetadata`.
- Add `RouteInputLocation`.
- Add `RouteInputMetadata`.
- Add `RouteBodyMetadata`.
- Add `RouteResponseMetadata`.
- Add `RouteDescription`.
- Add `Route.withMetadata(_:)`.
- Add `Route.describe(...)`.
- Add `Router.describeRoutes()`.
- Add `Application.describeRoutes()`.
- Preserve metadata through group prefixing and middleware attachment.
- Add behavior checks.
- Update README and AIDEV docs.

Non-goals:

- Full OpenAPI document generation.
- Schema derivation for Swift types.
- Macro metadata bridge.
- Documentation UI.
- Client SDK generation.

Target usage:

```swift
let app = Application {
    Post("/users") {
        Status.created
    }
    .describe(
        summary: "Create user",
        tags: ["Users"],
        inputs: [
            .header("x-daylily", type: "String"),
        ],
        requestBody: .json("CreateUserInput"),
        responses: [
            .response(.created, contentType: "application/json", type: "UserResponse"),
        ]
    )
}

let routes = app.describeRoutes()
```

Rules:

- Route metadata lives in `DaylilyCore`.
- Metadata describes routes but does not affect routing, middleware, lifecycle, body, or response behavior.
- Group prefixes must be reflected in route descriptions.
- Middleware attachment must preserve metadata.
- Type names are strings in this task; schema derivation is deferred.
- Macro lowering must use this runtime metadata later.

Steps:

- [x] 0014-001.1 Add route metadata value types.
- [x] 0014-001.2 Attach metadata to `Route`.
- [x] 0014-001.3 Add route/application description APIs.
- [x] 0014-001.4 Add behavior checks.
- [x] 0014-001.5 Update README and AIDEV docs.
- [x] 0014-001.6 Review, fix, validate, then finish the task.

Architecture impact:

- Extends `DaylilyCore` route modeling with descriptive metadata.
- Establishes the runtime source of truth for OpenAPI.
- Does not add a generator or new dependency.

Public API impact:

- Adds `RouteMetadata`.
- Adds `RouteInputLocation`.
- Adds `RouteInputMetadata`.
- Adds `RouteBodyMetadata`.
- Adds `RouteResponseMetadata`.
- Adds `RouteDescription`.
- Adds `Route.metadata`.
- Adds `Route.withMetadata(_:)`.
- Adds `Route.describe(...)`.
- Adds `Router.describeRoutes()`.
- Adds `Application.describeRoutes()`.

AIDEV updates required:

- `README.md`
- `README.zh-CN.md`
- `ai/aidev/start-here.md`
- `ai/aidev/project-map.md`
- `ai/aidev/architecture.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `ai/epics/0014-openapi-metadata.md`

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
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
```

Suggested checks:

- `Route.describe(...)` stores metadata.
- `Application.describeRoutes()` exposes normalized paths and metadata.
- Group prefixes are reflected in described paths.
- Route and group middleware do not erase metadata.
- `registry.yml` parses.
- `git diff --check` passes.
