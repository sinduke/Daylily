# 0020-002 Minimal App Template

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Provide a recommended minimal Daylily app structure for external projects.
- Keep the shape small, testable, and stable for humans and AI agents.
- Validate the template against both local checkout and released package dependency modes.

Scope:

- Add `templates/minimal-app`.
- Use an `AppCore` target for application construction and route declarations.
- Use an `App` executable target for process startup.
- Use `AppCoreTests` with `DaylilyTesting` for in-memory tests.
- Add `scripts/template-smoke-test.sh`.
- Add macOS and Linux CI coverage for template path and release modes.
- Update README, docs, roadmap, workflow, project map, and registry.

Non-goals:

- Add a full CLI generator.
- Add a permanent business example.
- Design dependency injection.
- Convert the template to macro-first until macro app construction has a testable app-export story.

Steps:

- [x] 0020-002.1 Define minimal external project structure.
- [x] 0020-002.2 Add template files.
- [x] 0020-002.3 Add template smoke script.
- [x] 0020-002.4 Add CI coverage.
- [x] 0020-002.5 Update docs and AIDEV.
- [x] 0020-002.6 Validate path and release modes.

Architecture impact:

- No framework runtime architecture changes.
- Establishes `AppCore` plus `App` executable as the recommended minimal external project shape.
- Path-mode smoke packages use an explicit `.package(name: "Daylily", path: ...)`
  dependency so the template remains stable when the repository checkout directory
  is not named `Daylily`.

Public API impact:

- None.

AIDEV updates required:

- Update project map for `templates/minimal-app` and `scripts/template-smoke-test.sh`.
- Update workflow validation commands.
- Update roadmap and registry to mark `0020-002-minimal-app-template` complete.

Validation:

- `scripts/template-smoke-test.sh --mode path`
- `scripts/template-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- `bash -n scripts/template-smoke-test.sh`
- `git diff --check`
- YAML parse for CI and registry
- Markdown local link/path sanity check
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`

Completed validation:

- `scripts/template-smoke-test.sh --mode path`
- `scripts/template-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- `scripts/consumer-smoke-test.sh --mode path`
- Linux Docker `swift:6.3.2-noble`: `scripts/template-smoke-test.sh --mode path`
- Linux Docker `swift:6.3.2-noble`: `scripts/template-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- `bash -n scripts/template-smoke-test.sh`
- `bash -n scripts/consumer-smoke-test.sh`
- `git diff --check`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`
- Markdown local link/path sanity check
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`

Notes:

- GitHub Actions did not create a push run for the initial 0020-002 commit, and
  `gh workflow run CI --ref main` returned GitHub HTTP 500 during this task. The
  CI workflow changes were validated by YAML parsing and by running the template
  path/release smoke tests locally on macOS and in the official Linux Swift
  Docker image.
