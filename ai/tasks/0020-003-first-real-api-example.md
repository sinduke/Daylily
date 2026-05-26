# 0020-003 First Real API Example

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Add a small real API example that feels closer to product work than Hello World.
- Keep the example usable as an external SwiftPM package.
- Validate the example against both local checkout and released package dependency modes.

Scope:

- Add `examples/commerce-api`.
- Use the same `AppCore` plus `App` executable shape as the minimal template.
- Demonstrate product listing, product lookup, order creation, order lookup, JSON DTOs, typed path/query inputs, route metadata, and actor-backed state.
- Add `scripts/example-smoke-test.sh`.
- Add macOS and Linux CI coverage for example path and release modes.
- Update README, docs, roadmap, workflow, project map, and registry.

Non-goals:

- Add a database or ORM.
- Add dependency injection before the DI design task.
- Add auth, payments, queues, or deployment features.
- Turn the example into a large tutorial app.

Steps:

- [x] 0020-003.1 Define the first real API domain and route surface.
- [x] 0020-003.2 Add the example SwiftPM package.
- [x] 0020-003.3 Add example smoke validation.
- [x] 0020-003.4 Add CI coverage.
- [x] 0020-003.5 Update docs and AIDEV.
- [x] 0020-003.6 Validate path and release modes.

Architecture impact:

- No framework runtime architecture changes.
- Establishes `examples/commerce-api` as the first product-shaped external example.
- Reuses the `AppCore` plus `App` executable project shape from `templates/minimal-app`.

Public API impact:

- None.

AIDEV updates required:

- Update project map for `examples/commerce-api` and `scripts/example-smoke-test.sh`.
- Update workflow validation commands.
- Update roadmap and registry to mark `0020-003-first-real-api-example` complete.

Validation:

- `scripts/example-smoke-test.sh --mode path`
- `scripts/example-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- `bash -n scripts/example-smoke-test.sh`
- `bash -n scripts/template-smoke-test.sh`
- `git diff --check`
- YAML parse for CI and registry
- Markdown local link/path sanity check
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`

Completed validation:

- `scripts/example-smoke-test.sh --mode path`
- `scripts/example-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- Linux Docker `swift:6.3.2-noble`: `scripts/example-smoke-test.sh --mode path`
- Linux Docker `swift:6.3.2-noble`: `scripts/example-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- `scripts/template-smoke-test.sh --mode path`
- `scripts/consumer-smoke-test.sh --mode path`
- `bash -n scripts/example-smoke-test.sh`
- `bash -n scripts/template-smoke-test.sh`
- `bash -n scripts/consumer-smoke-test.sh`
- `git diff --check`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`
- Markdown local link/path sanity check
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`
