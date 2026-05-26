# 0018-001 Beta Docs

Status: implemented
Epic: 0018-beta-docs

Goal:

- Add beta-facing documentation that helps a new reader understand, run, and evaluate Daylily quickly.
- Keep README as the flagship entry point while moving longer tutorial material into focused docs.
- Document current capabilities honestly without overstating planned ecosystem work.

Scope:

- Add a quickstart guide.
- Add example guides for JSON APIs, middleware, and testing.
- Add a capability matrix.
- Link the new docs from README and AIDEV where appropriate.
- Keep English and Simplified Chinese README entry points aligned.

Non-goals:

- Implement new runtime features.
- Add dependency injection, auth, ORM, queues, WebSocket, or deployment tooling.
- Publish benchmarks.
- Change public API.

Steps:

- [x] 0018-001.1 Create beta docs structure and quickstart.
- [x] 0018-001.2 Add focused JSON API, middleware, and testing examples.
- [x] 0018-001.3 Add capability matrix.
- [x] 0018-001.4 Link docs from README and AIDEV.
- [x] 0018-001.5 Review, validate, clean temporary handoff note, and finish.

Architecture impact:

- No runtime architecture changes.
- Documentation should continue to point at runtime APIs as the source of truth.

Public API impact:

- None.

AIDEV updates required:

- Update roadmap and registry to mark `0018-001-beta-docs` complete when finished.
- Update project map or start-here only if the docs structure becomes a new navigation surface.

Validation:

- `git diff --check`
- Link/path sanity check for new docs.
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`

Completed validation:

- `git diff --check`
- `ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'`
- Markdown local link/path sanity check
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`

Notes:

- Detailed README usage sections should remain available even after adding dedicated docs.
