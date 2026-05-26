# 0002-003 Bilingual README and AI-Native Introduction

Status: implemented
Epic: 0002-aidev-system

Steps:

- [x] 0002-003.1 Add bilingual README and AI-native introduction.

Goal:

- Write a public-facing English README.
- Add a Simplified Chinese README.
- Make the AI-native development model clear to users.
- Explain how AIDEV lets AI understand, use, upgrade, and extend the project quickly.

Scope:

- Replace `README.md` with a fuller English version.
- Add `README.zh-CN.md`.
- Update roadmap and registry numbering so macro route MVP becomes the next task.

Non-goals:

- Add new runtime behavior.
- Add macros.
- Change public Swift API.

Architecture impact:

- None.

Public API impact:

- None.

AIDEV updates required:

- Update roadmap.
- Update registry.
- Update project map if root files changed.

Validation:

- `swift build`
- `swift run HelloDaylily --check`

