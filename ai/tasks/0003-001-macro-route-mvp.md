# 0003-001 Macro Route MVP

Status: implemented
Epic: 0003-routing-macro-system

Steps:

- [x] 0003-001.1 Add route macro MVP.

Goal:

- Add the first macro route surface for Daylily.
- Support `@DaylilyServer`, `@GET`, and `@POST`.
- Generate a `static main() async throws` that lowers route methods into the existing runtime DSL.

Scope:

- Add macro implementation target.
- Add public macro declarations in `Daylily`.
- Support instance methods on a default-initializable server type.
- Support handlers with zero parameters.
- Support handlers with one `Request` parameter.
- Add a macro smoke type that must compile during `swift build`.
- Update AIDEV docs and registry.

Non-goals:

- `@Path`
- `@Body`
- `@GROUP`
- JSON
- Middleware
- OpenAPI
- Dependency injection
- Converting the default `swift run` entry away from the current runtime example

Architecture impact:

- Adds a macro layer that lowers into `DaylilyCore` runtime APIs.
- Keeps `DaylilyCore` independent from NIO and macro implementation details.

Public API impact:

- Adds `@DaylilyServer`.
- Adds `@GET`.
- Adds `@POST`.

AIDEV updates required:

- Update API registry.
- Update project map.
- Update architecture and concepts.
- Update roadmap and registry.

Validation:

- `swift build`
- `swift run HelloDaylily --check`
- external temporary client build with `@main @DaylilyServer`
