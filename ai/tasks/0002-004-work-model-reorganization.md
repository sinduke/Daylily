# 0002-004 Work Model Reorganization

Status: implemented
Epic: 0002-aidev-system

Goal:

- Replace the old flat task numbering model with an Epic / Task / Step model.
- Make tasks the smallest commit/push unit.
- Make steps reviewable and fixable without independent commits or pushes.
- Reorganize existing task files to match the new naming scheme.

Scope:

- Add `ai/epics/`.
- Rename existing task files to `NNNN-XXX-short-kebab-name.md`.
- Update `task-protocol.md` and `workflow.md`.
- Update roadmap, registry, README, prompt, and project map references.
- Add historical epic files for already implemented work.

Non-goals:

- Runtime code changes.
- Git branch strategy.
- Pull request workflow.
- Rewriting the full content of every historical task beyond the metadata needed for the new model.

Steps:

- [x] 0002-004.1 Define Epic / Task / Step hierarchy.
- [x] 0002-004.2 Rename existing task files.
- [x] 0002-004.3 Add epic files for current history.
- [x] 0002-004.4 Update workflow and task protocol.
- [x] 0002-004.5 Update AIDEV registry, roadmap, prompt, README, and project map.
- [x] 0002-004.6 User review.
- [x] 0002-004.7 Task finish commit/push after review.

Architecture impact:

- No runtime architecture impact.
- AI workflow now separates planning themes, commit units, and execution steps.

Public API impact:

- None.

AIDEV updates required:

- `AIDEV.md`
- `README.md`
- `README.zh-CN.md`
- `ai/aidev/task-protocol.md`
- `ai/aidev/workflow.md`
- `ai/aidev/roadmap.md`
- `ai/aidev/registry.yml`
- `ai/aidev/project-map.md`
- `ai/aidev/conventions.md`
- `ai/aidev/start-here.md`
- `ai/prompts/daylily-agent.md`
- `ai/epics/*`
- `ai/tasks/*`

Validation:

- `ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry ok"'`
- `ruby -e 'require "yaml"; r=YAML.load_file("ai/aidev/registry.yml"); paths=[]; paths += r.dig("aidev_files","epics") || []; paths += r.dig("aidev_files","tasks") || []; missing=paths.reject { |p| File.exist?(p) }; abort("missing: #{missing.join(", ")}") unless missing.empty?; puts "registered files ok"'`
- `git diff --check`

Completed validation:

- `registry ok`
- `registered files ok`
- `git diff --check`

Notes:

- This task applied the new review boundary before its own commit/push.
