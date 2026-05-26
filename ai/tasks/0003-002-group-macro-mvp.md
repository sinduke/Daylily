# 0003-002 Group Macro MVP

Status: implemented
Epic: 0003-routing-macro-system

Steps:

- [x] 0003-002.1 Add group macro MVP.

Goal:

- Add `@GROUP` for nested route groups.
- Let `@DaylilyServer` scan nested group structs and lower grouped routes into the existing runtime DSL.

Scope:

- Add public `@GROUP(_:)` macro declaration.
- Reuse marker macro implementation for `@GROUP`.
- Extend `@DaylilyServer` to scan nested structs annotated with `@GROUP`.
- Support group handlers with zero parameters or one `Request` parameter.
- Support nested group path prefixing through runtime route paths.
- Add macro smoke coverage.
- Update AIDEV docs and registry.

Non-goals:

- `@Path`
- `@Body`
- Middleware
- DI
- OpenAPI
- Changing default `swift run` to macro-only implementation

Architecture impact:

- Extends the macro layer.
- Keeps grouped routes lowered into runtime `Get` and `Post`.
- Keeps `DaylilyCore` unchanged.

Public API impact:

- Adds `@GROUP`.

AIDEV updates required:

- Update API registry.
- Update concepts, architecture, runtime contracts, extension playbooks, roadmap, and registry.

Validation:

- `swift build`
- `swift run HelloDaylily --check`
- `swift run` plus smoke request
- external temporary client build with `@main @DaylilyServer` and `@GROUP`
