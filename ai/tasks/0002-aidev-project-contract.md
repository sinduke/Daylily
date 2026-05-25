# 0002 AIDEV Project Contract

Status: implemented

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

