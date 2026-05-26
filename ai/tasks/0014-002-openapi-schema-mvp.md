# 0014-002 OpenAPI Schema MVP

Status: implemented
Epic: 0014-openapi-metadata

Goal:

- Generate a minimal OpenAPI document from runtime route metadata.
- Keep generation separate from `DaylilyCore`.
- Avoid source-code guessing and deep Swift schema reflection.

Scope:

- Add `DaylilyOpenAPI` product and target.
- Re-export `DaylilyOpenAPI` from `Daylily`.
- Add OpenAPI DTOs:
  - `OpenAPIDocument`
  - `OpenAPIInfo`
  - `OpenAPIOperation`
  - `OpenAPIParameter`
  - `OpenAPIRequestBody`
  - `OpenAPIResponse`
  - `OpenAPIMediaType`
  - `OpenAPISchema`
- Add `OpenAPIBuilder`.
- Add `Application.openAPI(title:version:openapi:)`.
- Map route metadata to OpenAPI paths, operations, parameters, request bodies, responses, and simple schemas.
- Add behavior checks.
- Update README and AIDEV docs.

Non-goals:

- Deep schema derivation from Swift types.
- Validation rule metadata.
- Security schemes.
- Documentation UI.
- Client SDK generation.
- Macro metadata lowering.

Target usage:

```swift
let document = app.openAPI(title: "Daylily Demo", version: "0.1.0")
let response = JSON(document)
```

Rules:

- `DaylilyOpenAPI` depends on `DaylilyCore`.
- `DaylilyCore` must not depend on `DaylilyOpenAPI`.
- `Application.openAPI(title:version:)` reads `Application.describeRoutes()`.
- Daylily `:name` path parameters map to OpenAPI `{name}` path segments.
- Path parameters are always required in OpenAPI output.
- Unknown Swift type names map to object schemas with `x-swift-type`.
- Routes without response metadata get a default `200 OK` response.

Steps:

- [x] 0014-002.1 Add `DaylilyOpenAPI` package product and target.
- [x] 0014-002.2 Add OpenAPI DTOs.
- [x] 0014-002.3 Add route description to OpenAPI builder.
- [x] 0014-002.4 Add `Application.openAPI(title:version:openapi:)`.
- [x] 0014-002.5 Add behavior checks.
- [x] 0014-002.6 Update README and AIDEV docs.
- [x] 0014-002.7 Review, fix, validate, then finish the task.

Architecture impact:

- Adds a user-facing OpenAPI helper module.
- Keeps route metadata storage in `DaylilyCore`.
- Keeps OpenAPI generation outside `DaylilyCore`.

Public API impact:

- Adds `DaylilyOpenAPI`.
- Adds OpenAPI DTOs.
- Adds `OpenAPIBuilder`.
- Adds `Application.openAPI(title:version:openapi:)`.
- Re-exports `DaylilyOpenAPI` from `Daylily`.

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

- `/users/:id` becomes `/users/{id}`.
- Path/query/header inputs become parameters.
- JSON body metadata becomes request body content.
- Response metadata becomes OpenAPI responses.
- Unknown Swift type names preserve `x-swift-type`.
- Routes without response metadata get `200 OK`.
- `registry.yml` parses.
- `git diff --check` passes.
