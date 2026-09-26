# Repeated independent application edits

This runner measures actual Codex CLI edits from incomplete starting fixtures.
It does not copy or replay the completed reference sources in `../application-changes`.
Each of three tasks runs twice in a new working directory and ephemeral CLI session:

1. Add a typed greeting endpoint while preserving health and exported route metadata.
2. Replace a hardwired provider using an application-owned typed dependency key.
3. Add a required author to request/response DTOs and explicit OpenAPI components.

The starting source, task text, and acceptance tests live under `fixtures/`. The
acceptance criteria are deliberately aligned with the existing three reference
exercises, but the completed source is never copied into a trial. The model sees
the task, starting source, acceptance tests, and copies of AIDEV API/runtime docs.
This is an open-test evaluation, not a blinded test or a general AI benchmark.

Run only when an actual account-consuming evaluation is intended:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  python3 ai/evals/repeated-changes/run.py --output /new/empty/result-directory --jobs 2
```

An existing ChatGPT Codex login and `codex exec` are required. No API key or paid
cloud resource is provisioned. The default model is the locally verified
`gpt-6-astra` with low reasoning; `--model` affects only these invocations. The
runner does not change Codex app settings or create app tasks. It ignores the
user CLI configuration for each invocation so unrelated configured MCP servers
are unnecessary. Model availability must be checked for the account before
substituting another model.

Only `Sources/` edits are allowed. The harness hashes all protected inputs,
restores the original acceptance tests and manifest, and runs `swift test`
independently after the model finishes. Success requires a completed model turn,
a nonempty source patch, intact protected inputs, and passing acceptance tests.
There is no model retry or automatic repair of a failed attempt. Prompt-based
read restrictions are audited in the event transcript; this is not a hermetic
security sandbox. Workspace writes are restricted by the Codex sandbox.

Each attempt records model wall time separately from acceptance build/test time,
total elapsed time, actual `turn.completed.usage`, a patch, and acceptance logs.
Unknown usage is `null`. Cost is explicitly `null`/unknown because ChatGPT CLI
reports no billable per-run amount; cached tokens are not converted into an
invented monetary estimate. Shared model prefix caches and compiler/download
caches may affect time; two copies do not establish statistical independence.

Recorded results are under [results/2026-09-26](results/2026-09-26/summary.json).
The exported event trace retains commands, file edits, completion and usage;
large command stdout is represented by a SHA-256. Raw transcript hashes are
recorded. This is a compact evidence export, not an unmodified raw transcript.

The [official noninteractive guide](https://learn.chatgpt.com/docs/non-interactive-mode)
and [OpenAI eval guidance](https://developers.openai.com/blog/eval-skills) describe
using structured CLI events and deterministic acceptance. The installed CLI help
is authoritative for the flags used by this local runner.


## Extended withheld-acceptance suite

`run.py` retains only the three original open-test fixtures. `run_extended.py` adds inventory reservations, durable JSON-file repository wiring, and body replay/outage repair. It archives an explicit published framework ref (alpha.3 by default), tests each incomplete baseline, removes acceptance sources before the model turn, and permits a separately recorded bounded repair using failure feedback. Initial editing must touch at least two source files.

```sh
python3 ai/evals/repeated-changes/run_extended.py --baseline-only --repetitions 1 --output /new/empty/baselines
# Opt-in actual account-consuming evaluation:
python3 ai/evals/repeated-changes/run_extended.py --framework-ref 0.1.0-alpha.3 --jobs 2 --repetitions 2 --output /new/empty/trials
```

Baseline mode requires Swift/Git/Python, makes no model calls, and can run in CI without Codex installed. Actual mode also requires the existing Codex login. Acceptance is withheld by workspace setup and read policy, not a hermetic adversarial boundary; baseline build artifacts exist but model reads are prohibited and audited. Raw events and all attempts are retained in output. [Recorded results](results/2026-09-26-alpha4/README.md) include 6/6 first-pass edits and no repairs; this remains a narrow fixed-task result.
