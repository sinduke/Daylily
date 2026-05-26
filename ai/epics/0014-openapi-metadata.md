# 0014 OpenAPI Metadata

Status: in-progress

Purpose:

- Generate useful API metadata after typed inputs and response/body conventions are clearer.
- Avoid premature OpenAPI design before handler shapes stabilize.

Target direction:

- Route metadata from runtime definitions.
- Macro-assisted metadata from typed handler inputs.
- JSON body and response metadata once body/response conventions mature.

Recommended tasks:

- `0014-001-route-metadata-runtime` (implemented)
- `0014-002-openapi-schema-mvp`
- `0014-003-macro-metadata-bridge`

Design notes:

- OpenAPI should describe Daylily's real runtime model.
- Avoid inventing metadata that macros cannot lower into runtime data.
- Typed handler inputs should inform path/body/query/header metadata.
- `0014-001` delivered runtime `RouteMetadata`, `Route.describe(...)`, and `Application.describeRoutes()`.

Non-goals for the first task:

- Full OpenAPI generator.
- Schema derivation for every Swift type.
- UI documentation site.
- Client SDK generation.
