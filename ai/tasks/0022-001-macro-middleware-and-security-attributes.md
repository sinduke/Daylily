# 0022-001 Macro Middleware and Security Attributes

Status: implemented
Epic: 0022-macro-middleware-and-security

Goal:

- Add macro attributes for application, group, and route middleware.
- Support named middleware expressions.
- Add explicit route security metadata that appears in generated OpenAPI operations.

Scope:

- Add public `@Use(...)` and `@Security(...)` macro declarations.
- Lower app-level `@Use(...)` to `Application.middleware(...)`.
- Lower group-level `@Use(...)` into inherited middleware for nested route declarations.
- Lower route-level `@Use(...)` to route `.middleware(...)`.
- Preserve middleware declaration order while retaining runtime application/group/route ordering.
- Add `RouteSecurityMetadata` and `RouteMetadata.security`.
- Add `security:` to `Route.describe(...)`.
- Map route security metadata to OpenAPI operation `security`.
- Add external consumer smoke coverage for app, group, route, and named middleware expressions.
- Update README, capability matrix, changelog, and AIDEV docs.

Non-goals:

- Inferring authentication or security metadata from middleware.
- Adding an authentication middleware framework.
- Adding OpenAPI `components.securitySchemes`.
- Adding a middleware registry DSL.
- Supporting multiple arguments, arrays, or keyless lookup in `@Use(...)`.
- Supporting scoped `@Security` arguments beyond scheme name in this slice.

Implemented:

- `@Use(...)` accepts one top-level Swift expression and can be repeated.
- `@Use(...)` is supported on the `@DaylilyServer` type, `@GROUP` nested structs, and route methods.
- `@Security("name")` is supported on route methods and lowers to `RouteSecurityMetadata.requirement("name")`.
- `OpenAPIOperation.security` emits operation-level security requirements when metadata is present.
- Consumer path-mode smoke validates app, group, route, and named middleware execution through response headers.

Validation:

- `swift build`
- `swift test`
- `swift run HelloDaylily --check`
- `scripts/consumer-smoke-test.sh --mode path`
- `bash -n scripts/consumer-smoke-test.sh scripts/template-smoke-test.sh scripts/example-smoke-test.sh`
- `ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); YAML.load_file(".github/workflows/ci.yml"); puts "yaml ok"'`
- `git diff --check`
