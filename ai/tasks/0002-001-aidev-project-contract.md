# 0002-001 AIDEV Project Contract

Status: implemented
Epic: 0002-aidev-system

Steps:

- [x] 0002-001.1 Create AIDEV project contract.

Goal:

- Create an AIDEV entry point for AI-driven development.
- Capture current project map, architecture boundaries, API surface, parameter conventions, workflow, and roadmap.
- Make future AI work less dependent on chat memory.

Scope:

- Add `AIDEV.md`.
- Add `ai/aidev/` documentation.
- Add machine-readable `registry.yml`.
- Update README to point at AIDEV.

Non-goals:

- Build a command-line aidev tool.
- Add macros.
- Change runtime behavior.

Validation:

- `swift build`
- `swift run HelloDaylily --check`

