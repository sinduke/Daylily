# 0020-009 Keyed Dependencies Runtime

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Implement the accepted typed `DependencyKey<Value>` runtime API.
- Support protocol-oriented dependency lookup and same-type multi-instance lookup.
- Keep the existing concrete-type `Dependencies` registry as the simple path.
- Keep macro syntax deferred until runtime behavior is real and tested.

Scope:

- Add public `DependencyKey<Value>` in `DaylilyCore`.
- Add keyed `Dependencies.register(_:for:)`, `get(_:)`, and `require(_:)`.
- Keep keyed identity based on value type and key name.
- Extend missing dependency errors so keyed misses include both value type and key name.
- Add behavior checks for keyed replacement, same-name different-type lookup, same-type multi-instance lookup, existential values, handler access, and missing keyed errors.
- Update docs, AIDEV, roadmap, registry, and capability status.

Non-goals:

- `@Dependency` macro syntax.
- Lifecycle-managed services.
- Async factories.
- Request-scoped dependency registration.
- Default values.
- Direct protocol metatype lookup.
- String-only lookup.
- Replacing project-owned composition roots or service containers.

Steps:

- [x] 0020-009.1 Add keyed runtime API.
- [x] 0020-009.2 Add behavior checks.
- [x] 0020-009.3 Update docs and AIDEV.
- [x] 0020-009.4 Validate root package and smoke surfaces.
- [x] 0020-009.5 Finish task status.

Architecture impact:

- `DependencyKey<Value>` lives in `DaylilyCore`.
- `Dependencies` remains NIO-free and app-wide.
- Keyed lookup is an extension of `Dependencies`, not a new container.
- Runtime APIs remain the source of truth before any macro sugar.

Public API impact:

```swift
public struct DependencyKey<Value>: Sendable {
    public let name: String

    public init(_ name: String)
}

public extension Dependencies {
    mutating func register<Value: Sendable>(_ value: Value, for key: DependencyKey<Value>)
    func get<Value: Sendable>(_ key: DependencyKey<Value>) -> Value?
    func require<Value: Sendable>(_ key: DependencyKey<Value>) throws -> Value
}
```

Behavior:

- Concrete-type lookup remains unchanged.
- Keyed lookup identity includes the `Value` type and key name.
- Re-registering the same key replaces the previous value.
- Two keys with the same value type and different names address different slots.
- Two keys with different value types and the same name address different slots.
- Protocol-oriented lookup is expressed with existential value keys such as `DependencyKey<any ProductServing>`.
- Missing keyed dependencies throw `DependencyError` with both value type and key name in the reason.

AIDEV updates required:

- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/roadmap.md`
- `ai/aidev/start-here.md`
- `ai/aidev/registry.yml`
- Release readiness and user docs that describe dependency status.

Validation:

- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`
- `scripts/example-smoke-test.sh --mode path`
- `scripts/template-smoke-test.sh --mode path`
- `scripts/consumer-smoke-test.sh --mode path`
- `git diff --check`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`

Completed validation:

- Passed `swift build`.
- Passed `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`.
- Passed `swift run HelloDaylily --check`.
- Passed `scripts/example-smoke-test.sh --mode path`.
- Passed `scripts/template-smoke-test.sh --mode path`.
- Passed `scripts/consumer-smoke-test.sh --mode path`.
- Passed YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- Passed `git diff --check`.
- Passed stale status scan for old keyed-runtime-not-implemented and `0020-009-macro-dependency` references.

Notes:

- This task intentionally supersedes the previous direct jump to `0020-009 Macro @Dependency`.
- Future macro dependency syntax should become `0020-010` after this runtime contract is stable.
