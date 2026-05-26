# 0019-001 Release Hygiene

Status: implemented
Epic: 0019-release-hygiene

Goal:

- Prepare Daylily for external trial by tightening CI, release notes, and release-readiness documentation.
- Make platform support and current experimental status explicit.
- Keep public API registry and project docs aligned with the release hygiene surface.

Scope:

- Add or update GitHub Actions CI for macOS and Linux validation where feasible.
- Add `CHANGELOG.md`.
- Add release-readiness documentation.
- Update README/docs/AIDEV navigation for release status.
- Update registry and roadmap.

Non-goals:

- Create a Git tag.
- Publish a package release.
- Add new runtime features.
- Add production deployment tooling.
- Claim production readiness.

Steps:

- [x] 0019-001.1 Review current CI and toolchain constraints.
- [x] 0019-001.2 Add release notes and release-readiness docs.
- [x] 0019-001.3 Update CI for release hygiene.
- [x] 0019-001.4 Update README, docs, AIDEV, roadmap, and registry.
- [x] 0019-001.5 Validate, clean temporary handoff note, and finish.

Architecture impact:

- No runtime architecture changes.

Public API impact:

- None expected.

AIDEV updates required:

- Update roadmap and registry to mark `0019-001-release-hygiene` complete when finished.
- Update project map/start-here if new docs become navigation surfaces.

Validation:

- `git diff --check`
- YAML parse for registry and CI workflow
- Markdown local link/path sanity check
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`

Completed validation:

- `git diff --check`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`
- Markdown local link/path sanity check
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`

Notes:

- If Linux cannot be proven locally, document that CI is the source of truth for Linux validation.
- Local Docker Linux simulation with `swift:6.3.2-noble` was attempted, but the image pull did not complete in a reasonable time. GitHub Actions is the source of truth for Linux validation.
