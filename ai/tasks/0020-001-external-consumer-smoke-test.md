# 0020-001 External Consumer Smoke Test

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Verify Daylily can be consumed from a fresh external SwiftPM package.
- Cover both current checkout pre-release validation and the published `0.1.0-alpha.1` package path.
- Add a repeatable release gate instead of relying on one-off manual package tests.

Scope:

- Add `scripts/consumer-smoke-test.sh`.
- Generate a temporary Swift package outside the Daylily repository.
- Validate local path dependency mode.
- Validate released package dependency mode using `0.1.0-alpha.1`.
- Compile a runtime DSL executable.
- Compile a macro executable using `@main @DaylilyServer`.
- Run a Swift Testing target that imports `Daylily` and `DaylilyTesting`.
- Add macOS and Linux CI coverage for the smoke test.
- Update release docs and AIDEV.

Non-goals:

- Add a permanent example app.
- Design dependency injection.
- Add a CLI/template generator.
- Run a long-lived external server during smoke tests.

Steps:

- [x] 0020-001.1 Define release and pre-release consumer smoke modes.
- [x] 0020-001.2 Generate a fresh Swift package with runtime, macro, and testing targets.
- [x] 0020-001.3 Add CI coverage on macOS and Linux.
- [x] 0020-001.4 Update docs, changelog, roadmap, and registry.
- [x] 0020-001.5 Validate local path and release modes.

Architecture impact:

- No runtime architecture changes.
- Adds an external consumer verification boundary for package identity, products, macros, and testing helpers.

Public API impact:

- None.

AIDEV updates required:

- Update workflow validation commands.
- Update project map for `scripts/consumer-smoke-test.sh`.
- Update roadmap and registry to place `0020` after the alpha release.

Validation:

- `scripts/consumer-smoke-test.sh --mode path`
- `scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- `git diff --check`
- YAML parse for CI and registry
- Markdown local link/path sanity check
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`

Completed validation:

- `scripts/consumer-smoke-test.sh --mode path`
- `scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- `bash -n scripts/consumer-smoke-test.sh`
- `git diff --check`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`
- Markdown local link/path sanity check
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`
