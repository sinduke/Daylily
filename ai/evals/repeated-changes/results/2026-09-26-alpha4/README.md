# Extended actual AI edits — 2026-09-26

Six actual Codex edits (three new tasks × two fresh workspaces) passed first-attempt withheld acceptance; zero repair attempts were needed. Each incomplete baseline compiled and failed its behavioral acceptance. Every successful edit changed at least two source files; protected inputs and the framework snapshot were unchanged.

Tasks: atomic/idempotent inventory reservations; durable JSON file repository integration; one-shot body replay and dependency-outage repair. These extend the earlier endpoint/dependency/DTO tasks, rather than re-running the same six cases. File persistence is not a PostgreSQL-driver evaluation; the separate commerce deployment covers PostgreSQL.

Framework snapshot: published `0.1.0-alpha.3`, commit `cfa835792cca3cce614999ddc7adca290015a801`. The harness archives that exact commit and records the archive hash. This is immutable source provenance, not a SwiftPM Git resolver test. Model: `gpt-6-astra`, low reasoning. Model time ranged from 44.713 to 61.559 seconds; total runner wall time was 237.628 seconds including baseline/acceptance builds.

Usage fields reported by the CLI (aggregate): `{"cache_write_input_tokens": 0, "cached_input_tokens": 747520, "input_tokens": 862144, "output_tokens": 6100, "reasoning_output_tokens": 121}`. Monetary cost is unknown; no token-to-cost estimate is substituted. Shared compiler/download/model caches affect timings.

The model receives TASK.md, Sources and version-matched API/runtime docs. Acceptance sources are never installed during a model turn; an empty test placeholder remains. The baseline compilation leaves build artifacts, whose reads are forbidden by the prompt. Command transcripts were reviewed: no acceptance/build/reference reads or external tools were observed. This protocol is not a hermetic secrecy boundary or a general AI success-rate estimate. An optional repair receives failure feedback and is tracked separately; none occurred here.

Evidence preserves baseline and final acceptance logs, source patches, prompts, per-attempt usage and commands. Exported transcripts replace command stdout with SHA-256/length while preserving command names, edits and completion/usage events. Raw transcript hashes are included. Local raw evidence remains in `/tmp/daylily-alpha4-ai-trials-1`; the exported traces are deliberately compact, not raw transcripts.

Reproduce (consumes the existing configured Codex account):

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  python3 ai/evals/repeated-changes/run_extended.py \
  --framework-ref 0.1.0-alpha.3 --jobs 2 --repetitions 2 \
  --output /new/empty/daylily-extended-ai
```

`--baseline-only --repetitions 1` validates the three incomplete starters without making model calls.
