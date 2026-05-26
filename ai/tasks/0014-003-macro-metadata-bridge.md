# 0014-003 Macro Metadata Bridge

Status: implemented
Epic: 0014-openapi-metadata

Goal:

- Connect macro typed handler inputs to runtime route metadata.
- Ensure macro routes and handwritten routes use the same OpenAPI metadata model.
- Avoid a parallel macro-only metadata system.

Scope:

- Update `@DaylilyServer` lowering for `@Path`.
- Update `@DaylilyServer` lowering for `@Query`.
- Update `@DaylilyServer` lowering for `@Header`.
- Update `@DaylilyServer` lowering for `@JSONBody`.
- Generate `Route.describe(inputs:requestBody:)` on macro-created routes when metadata exists.
- Keep extraction behavior unchanged.
- Use existing macro smoke coverage for compile verification.
- Update README and AIDEV docs.

Non-goals:

- New public macros.
- Summary/description/tag macro syntax.
- Response schema inference.
- Full Swift type schema derivation.
- Macro middleware attributes.

Lowering:

```text
@Path      -> RouteInputMetadata.path(...)
@Query     -> RouteInputMetadata.query(...)
@Header    -> RouteInputMetadata.header(...)
@JSONBody  -> RouteBodyMetadata.json(...)
```

Rules:

- Macro lowering must keep runtime extraction as behavior source of truth.
- Macro metadata must use `Route.describe(...)`.
- Macro metadata must use `RouteInputMetadata` and `RouteBodyMetadata` from `DaylilyCore`.
- Handwritten route metadata and macro-generated route metadata must feed the same `DaylilyOpenAPI` builder.
- No separate macro metadata registry is allowed.

Steps:

- [x] 0014-003.1 Collect metadata while lowering macro handler parameters.
- [x] 0014-003.2 Generate `.describe(...)` for routes with typed input metadata.
- [x] 0014-003.3 Preserve existing handler extraction behavior.
- [x] 0014-003.4 Verify macro smoke compilation through build/check.
- [x] 0014-003.5 Update README and AIDEV docs.
- [x] 0014-003.6 Review, fix, validate, then finish the task.

Architecture impact:

- Completes the first OpenAPI metadata loop:
  - runtime route metadata
  - OpenAPI document generation
  - macro typed input metadata lowering
- Keeps runtime APIs as the source of truth.
- Keeps macro syntax as sugar over runtime behavior and metadata.

Public API impact:

- No new public names.
- Existing macro-generated routes now include route metadata for typed inputs.

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

- Existing macro smoke routes still compile.
- `@Path` metadata generation compiles.
- `@Query` metadata generation compiles.
- `@Header` metadata generation compiles.
- `@JSONBody` metadata generation compiles.
- `registry.yml` parses.
- `git diff --check` passes.
