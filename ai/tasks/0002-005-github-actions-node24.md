# 0002-005 GitHub Actions Node 24

Status: implemented
Epic: 0002-aidev-system

Goal:

- Remove the GitHub Actions Node.js 20 deprecation warning from Daylily CI.
- Keep CI behavior otherwise unchanged.

Scope:

- Upgrade `actions/checkout` in `.github/workflows/ci.yml` from the Node.js 20-backed version to a Node.js 24-backed version.
- Update AIDEV task/registry/roadmap records.

Non-goals:

- Changing CI runner OS.
- Adding caches.
- Changing Swift build/check commands.
- Changing branch or pull request strategy.

Steps:

- [x] 0002-005.1 Confirm current checkout action version.
- [x] 0002-005.2 Upgrade checkout action to a Node.js 24-backed version.
- [x] 0002-005.3 Update AIDEV registry and roadmap.
- [x] 0002-005.4 Validate locally and through GitHub Actions.
- [x] 0002-005.5 Finish task commit/push.

Architecture impact:

- None.

Public API impact:

- None.

AIDEV updates required:

- `.github/workflows/ci.yml`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `ai/epics/0002-aidev-system.md`
- `ai/tasks/0002-005-github-actions-node24.md`

Validation:

- `ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry ok"'`
- `git diff --check`
- `swift build`
- `swift run HelloDaylily --check`
- GitHub Actions CI must pass without the Node.js 20 checkout warning.

Completed validation:

- `registry ok`
- `git diff --check`
- `swift build`
- `swift run HelloDaylily --check`

Notes:

- Official `actions/checkout` documentation shows `actions/checkout@v6` as the current usage example, and records that checkout v5 moved to the Node.js 24 runtime.
