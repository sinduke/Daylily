# 0010-001 Typed Path Extraction Runtime

Status: implemented
Epic: 0010-typed-handler-inputs

Goal:

- Add runtime typed extraction for path parameters.
- Make the first typed handler input building block available before macro sugar.
- Keep `DaylilyCore` small and Foundation-free.

Scope:

- Add a public `ParameterDecodable` protocol.
- Add typed accessors to `Parameters`.
- Add a `ParameterError` response error for missing and invalid path parameters.
- Support first-version standard library types:
  - `String`
  - `Int`
  - `Double`
  - `Bool`
- Map missing and invalid parameters to `400 Bad Request`.
- Add behavior checks.
- Update AIDEV documentation and README examples.

Non-goals:

- `@Path` macro syntax.
- `UUID` support.
- Query/header/cookie extraction.
- JSON body macro.
- Validation framework.
- Foundation dependency in `DaylilyCore`.

Steps:

- [x] 0010-001.1 Define `ParameterDecodable`.
- [x] 0010-001.2 Add typed `Parameters.require(_:as:)`.
- [x] 0010-001.3 Add optional typed `Parameters.get(_:as:)`.
- [x] 0010-001.4 Add `ParameterError` with clear 400 mappings.
- [x] 0010-001.5 Add checks for success, missing, invalid, and supported scalar types.
- [x] 0010-001.6 Update AIDEV docs, README examples, and registry.
- [x] 0010-001.7 Review, fix, validate, then finish the task.

Target API:

```swift
public protocol ParameterDecodable: Sendable {
    static var parameterTypeDescription: String { get }
    static func decodeParameter(_ value: String) -> Self?
}

public extension Parameters {
    func require<Value: ParameterDecodable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws -> Value

    func get<Value: ParameterDecodable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws -> Value?
}
```

Target usage:

```swift
Get("/users/:id") { request in
    let id = try request.parameters.require("id", as: Int.self)
    return "User \(id)"
}
```

Error behavior:

```text
Missing path parameter: id
Invalid path parameter id: expected Int
```

Both map to:

```text
400 Bad Request
```

Design notes:

- `String` remains available through the existing optional subscript and through `require(_:as:)`.
- `UUID` is deliberately deferred because it would require a Foundation decision.
- The first macro task should lower `@Path` into this runtime API.

AIDEV updates required:

- `ai/aidev/runtime-contracts.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/concepts.md`
- `ai/aidev/conventions.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `README.md`
- `README.zh-CN.md`

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
swift run
curl -i http://127.0.0.1:8080/hello
curl -i http://127.0.0.1:8080/users/42
curl -i http://127.0.0.1:8080/users/not-int
```

Suggested checks:

- Typed `Int` path extraction succeeds.
- Typed `Double` path extraction succeeds.
- Typed `Bool` path extraction succeeds.
- Missing path parameter returns 400 with a clear reason.
- Invalid path parameter returns 400 with a clear reason.
- Optional typed get returns nil when missing.
- Optional typed get throws when present but invalid.

Notes:

- This is the first concrete step toward typed handler inputs.
- Keep this runtime-first. Macro sugar comes next.
