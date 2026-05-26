# 0010-004 Query and Header Inputs

Status: implemented
Epic: 0010-typed-handler-inputs

Goal:

- Add typed query and header extraction.
- Extend macro handler inputs beyond path and JSON body.
- Keep the extraction model consistent with `ParameterDecodable`.

Scope:

- Add `QueryParameters`.
- Add query parsing to `Request`.
- Preserve route matching by stripping query text from `Request.path`.
- Add `Headers.require(_:as:)` and `Headers.get(_:as:)`.
- Add `QueryParameterError` and `HeaderError` with clear `400 Bad Request` reasons.
- Add public `@Query` and `@Header` marker wrappers.
- Extend `@DaylilyServer` lowering for `@Query` and `@Header`.
- Add top-level and grouped macro smoke coverage.
- Add `HelloDaylily --check` coverage.
- Update README and AIDEV docs.

Non-goals:

- Optional macro parameters.
- Repeated query values.
- Full URL/form parser.
- Cookie extraction.
- Foundation-backed types such as `UUID`.
- OpenAPI metadata.

Target usage:

```swift
@GET("/search")
func search(
    @Query term: String,
    @Query("page") pageNumber: Int,
    @Header("x-daylily") token: String
) -> String {
    "\(term):\(pageNumber):\(token)"
}
```

Target lowering:

```swift
Get("/search") { req in
    server.search(
        term: try req.query.require("term", as: String.self),
        pageNumber: try req.query.require("page", as: Int.self),
        token: try req.headers.require("x-daylily", as: String.self)
    )
}
```

Rules:

- `@Query` and `@Header` are marker wrappers in `DaylilyCore`.
- Runtime extraction is the source of truth.
- Bare `@Query` / `@Header` uses the Swift local parameter name.
- `@Query("name")` / `@Header("name")` maps to an explicit input name.
- Missing query values map to `400 Missing query parameter: <name>`.
- Invalid query values map to `400 Invalid query parameter <name>: expected <type>`.
- Missing headers map to `400 Missing header: <name>`.
- Invalid headers map to `400 Invalid header <name>: expected <type>`.
- Query parsing is small and in-core: `&` pairs, `name=value`, empty values, `+` as space, percent-decoded UTF-8 bytes, last value wins for repeated names.
- Header lookup remains case-insensitive through `Headers`.

Steps:

- [x] 0010-004.1 Add runtime query model and parser.
- [x] 0010-004.2 Add typed query/header extraction.
- [x] 0010-004.3 Add `@Query` and `@Header` marker wrappers.
- [x] 0010-004.4 Extend macro lowering.
- [x] 0010-004.5 Add checks and macro smoke coverage.
- [x] 0010-004.6 Update README and AIDEV docs.
- [x] 0010-004.7 Review, fix, validate, then finish the task.

Architecture impact:

- Expands `DaylilyCore` with typed query/header extraction.
- Keeps Foundation out of `DaylilyCore`.
- Keeps macros as lowering sugar over runtime APIs.
- Updates NIO request construction to preserve the request target so `Request` can parse query text.

Public API impact:

- Adds `Request.query`.
- Adds `QueryParameters`.
- Adds `QueryParameterError`.
- Adds `HeaderError`.
- Adds `Headers.require(_:as:)`.
- Adds `Headers.get(_:as:)`.
- Adds `@Query`.
- Adds `@Header`.

AIDEV updates required:

- `README.md`
- `README.zh-CN.md`
- `ai/aidev/start-here.md`
- `ai/aidev/project-map.md`
- `ai/aidev/architecture.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/concepts.md`
- `ai/aidev/conventions.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `ai/epics/0010-typed-handler-inputs.md`

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
swift build -Xswiftc -Xfrontend -Xswiftc -dump-macro-expansions 2>&1 | rg -n 'req\.query\.require|req\.headers\.require|Macro search'
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
```

Suggested checks:

- Query parsing strips `?` from `Request.path` so routing still works.
- `request.query.require("page", as: Int.self)` succeeds.
- Missing/invalid query values return clear 400 responses.
- `request.headers.require("x-count", as: Int.self)` succeeds case-insensitively.
- Missing/invalid headers return clear 400 responses.
- `@Query` and `@Header` compile in top-level and grouped macro routes.
- Macro expansion lowers to `req.query.require(...)` and `req.headers.require(...)`.
- `registry.yml` parses.
- `git diff --check` passes.
