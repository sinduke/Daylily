# 0026-005 Broader AI Application Edits

Status: implemented
Epic: 0026-real-business-and-sustained-operation

Goal:

- Measure actual cross-file business changes, persistence integration and fault repair using immutable withheld acceptance.

Scope:

- Execute the corresponding authorized alpha.4 checklist slice.

Non-goals:

- A new published version tag, paid infrastructure, or a claim of production certification.

Steps:

- [x] 0026-005.1 Extend the harness for explicit source revision, withheld tests, baseline failure and bounded repair attempts.
- [x] 0026-005.2 Add independently solvable cross-file business, persistence and repair fixtures.
- [x] 0026-005.3 Validate acceptance against incomplete baselines and test harness invariants.
- [x] 0026-005.4 Run repeated actual model edits and preserve first-pass/repair/time/token/failure evidence.

Architecture impact:

- Opt-in local evaluation tooling only; no automatic account-consuming CI runs.

Public API impact:

- None directly; integrated API changes are documented by their owning tasks.

AIDEV updates required:

- Workflow, project map, roadmap, registry and relevant user-facing validation guides.

Validation:

- Baseline acceptance must fail, model attempts must edit Sources only, evaluation uses a fixed source revision, protected acceptance runs after editing; report outcomes honestly.

Notes:

- All six actual trials and the independent evidence review are complete. Integrated candidate CI and deployment acceptance are recorded in 0026-006.

Completed evidence:

- Three new starters compile and fail two behavioral tests each; baseline-only validation also passes with `--codex /does-not-exist`, proving no CLI/model invocation is needed.
- Six actual edits (three tasks × two independent workspaces), all first-pass accepted, no repairs. All protected inputs and immutable alpha.3 archive remained unchanged, with at least two source files changed per trial.
- Model wall time 44.713–61.559 seconds; full parallel runner 237.628 seconds. CLI reports 862,144 input tokens (747,520 cached) and 6,100 output tokens; monetary cost remains unknown.
- Evidence: `ai/evals/repeated-changes/results/2026-09-26-alpha4/README.md`, including baseline/final logs, patches, usage, command transcripts and raw transcript hashes.
- Independent review checked all TASK/holdout/patches, six distinct CLI thread IDs, archive/fixture/transcript hashes, source diffs, first-pass/repair statistics and command read boundaries; no blocking issue.
- Legacy runner excludes HoldoutTests fixtures so its original open-test command remains valid. Shared AIDEV/README/candidate docs describe the new opt-in command; CI adds baseline-only checks. Final candidate CI remains owned by 0026-006.
