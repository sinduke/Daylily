# 0022 Macro Middleware and Security Metadata

Status: implemented

Goal:

- Let macro apps attach middleware at application, group, and route scope.
- Support named middleware bundle expressions without adding a registry or magic lookup layer.
- Let macro routes expose explicit OpenAPI security requirements without inferring security from middleware.

Sequence:

```text
0022-001 Macro Middleware and Security Attributes (delivered)
```

Delivered:

- `@Use(...)` on `@DaylilyServer` types lowers to application middleware.
- `@Use(...)` on `@GROUP` nested structs lowers to inherited group middleware for child routes.
- `@Use(...)` on route methods lowers to route middleware.
- `@Use(...)` accepts a single top-level Swift expression, including named values such as `AppMiddleware.observability`.
- `@Security("schemeName")` lowers to route metadata and OpenAPI operation `security`.

Design stance:

- Macro middleware is syntax over the existing runtime `.middleware(...)` API.
- Group middleware lowering should preserve runtime order: application, outer group, inner group, route.
- Security metadata is explicit documentation metadata and is not inferred from middleware.
- Security scheme definitions remain outside this slice; this slice only records operation-level requirements.
