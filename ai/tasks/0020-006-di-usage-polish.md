# 0020-006 DI Usage Polish

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Polish the first `Dependencies` usage guidance without expanding runtime scope.
- Make the project-owned `makeApplication` pattern explicit.
- Document test override choices.
- Decide how the minimal template should handle lightweight dependency examples.

Scope:

- Keep the runtime API unchanged.
- Prefer domain-specific `makeApplication(...)` parameters for common test overrides.
- Keep `configureDependencies` as an explicit escape hatch for registry-level wiring.
- Add a dedicated dependencies usage guide.
- Keep `templates/minimal-app` source free of `Dependencies` until a future tag includes the API, so release template smoke remains compatible with `0.1.0-alpha.1`.
- Add an optional minimal-template README snippet for adding dependencies later.
- Update README, docs, AIDEV, registry, roadmap, and changelog.

Non-goals:

- Protocol or existential dependency lookup.
- Keyed dependencies.
- Lifecycle integration.
- `@Dependency` macro syntax.
- Request-scoped dependencies.
- Making `Dependencies` mandatory for user applications.

Decisions:

- `makeApplication` should be the project-owned composition point.
- Domain-specific overrides such as `makeApplication(store:)` are preferred for normal business tests.
- `makeApplication(configureDependencies:)` is still available for advanced tests and direct registry exercises.
- The minimal app template should stay as small and release-compatible as possible; dependency usage belongs in docs until the current API is tagged.
- The commerce API remains the concrete source example for app-wide dependency wiring.

Validation:

- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`
- `swift test` in `examples/commerce-api`
- `scripts/template-smoke-test.sh --mode path`
- `scripts/template-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- `scripts/example-smoke-test.sh --mode path`
- `git diff --check`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`

Completed validation:

- Passed `swift build`.
- Passed `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`.
- Passed `swift run HelloDaylily --check`.
- Passed `swift test` in `examples/commerce-api`.
- Passed `scripts/template-smoke-test.sh --mode path`.
- Passed `scripts/template-smoke-test.sh --mode release --version 0.1.0-alpha.1`.
- Passed `scripts/example-smoke-test.sh --mode path`.
- Passed YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- Passed `git diff --check`.
- Passed trailing whitespace scan for touched source, docs, examples, templates, and AIDEV files.
