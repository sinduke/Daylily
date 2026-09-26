# Recorded independent trials — 2026-09-26

Six fresh Codex CLI sessions edited incomplete application sources. All six passed the fixed acceptance tests; all protected inputs remained unchanged. Baseline sources independently failed acceptance before any requested implementation was present.

Model: `gpt-6-astra`, low reasoning. CLI: `0.155.0-alpha.9.2`, existing ChatGPT login. Two concurrent workers; total runner wall time **177.072 seconds**.

| Task | Run | Acceptance | Model seconds | Verification seconds | Input tokens | Cached input | Output tokens |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 01-add-endpoint | 1 | pass | 35.607 | 21.348 | 105316 | 90880 | 504 |
| 01-add-endpoint | 2 | pass | 39.826 | 17.845 | 132573 | 116096 | 566 |
| 02-replace-dependency | 1 | pass | 42.027 | 16.880 | 149608 | 128256 | 571 |
| 02-replace-dependency | 2 | pass | 37.677 | 16.720 | 114651 | 94720 | 500 |
| 03-evolve-dto | 1 | pass | 38.443 | 16.635 | 80347 | 59392 | 655 |
| 03-evolve-dto | 2 | pass | 44.848 | 16.298 | 108679 | 90112 | 706 |

**Cost: unknown.** No per-run billed cost was reported; no API-price conversion was inferred. Usage fields are the CLI-reported totals, including cached input. Input token counts include repeated model turns and provided context, not only task prompt text.

Each trial has its actual patch, compact event evidence, result JSON and acceptance log. The three [baseline results](baseline-results.json) each record a nonzero acceptance exit code. The original raw transcripts and full build logs are retained at `/tmp/daylily-ai-repeated-20260926` for this session; exported evidence omits command stdout/build chatter and records raw transcript SHA-256 values.

Manual trace/patch review confirmed local fixture/doc reads, real file changes, and no reads of the completed reference implementations. Both dependency trials introduced a typed protocol dependency key and resolved it in the handler. DTO trials retained the old source initializer as a compatibility overload while requiring author in decoded JSON and exported schemas.

These are six open-test observations on three small fixed tasks, not a statistically generalizable success rate. Models, context caches, and build caches were shared; sources and conversation sessions were fresh for each trial. Acceptance used the working-tree framework dependency, not an immutable release pin.
