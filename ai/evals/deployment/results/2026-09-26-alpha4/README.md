# Alpha.4 sustained deployment evidence — 2026-09-26

Validated candidate: `1f8e0ea5f149b09cc398d302bf37c5cd63258452`. Latest published tag remains alpha.3; this acceptance does not create a new release.

- [Complete CI: 12/12 jobs](https://github.com/sinduke/Daylily/actions/runs/36244501153); [retained independent CI audit](ci-audit.md) and [artifact hashes](ci-artifact-hashes.md).
- [One-hour Linux run](https://github.com/sinduke/Daylily/actions/runs/36244505313): 3600.175 seconds; 223,821 successful requests; 20 expected database 503s; zero unexpected failures; 494 resource records (493 complete samples and one planned restart gap); peak RSS 36,248 KiB; zero cleanup errors.
- [Retained one-hour result](hour-result.md) and [raw artifact hashes](hour-artifact-hashes.md).

The parent independently recomputed traffic outcomes and outage time-window overlap from every traffic row, per-process resource medians and coverage from every resource row, captured Git build-tree hash, executed harness hash, image source labels/architectures, public TLS root hash, and all 16 dependency pins. The one-hour artifact is available as `sustained-business-Linux` in its run. Raw traffic/logs are retained there; summaries and hashes are committed here. Original local downloads remain at `/tmp/daylily-alpha4-hour-final` and the independent audit at `/tmp/daylily-alpha4-hour-evidence-audit.json`.

Earlier failed candidates are preserved in [full attempt 1](https://github.com/sinduke/Daylily/actions/runs/36243752464) and [hour attempt 1](https://github.com/sinduke/Daylily/actions/runs/36243761973). They were not accepted: Linux required FoundationNetworking for the contract fixture, Python 3.12 exposed a completed-response socket bug in the harness, and Linux persistent artifact paths initially omitted resolver files. Corrected candidate CI includes 13 real TCP reader regressions and checks the actual uploaded resolver records.

The trial uses paced traffic, private ephemeral containers, a local trusted CA with hostname verification, and database TLS disabled inside that isolated network. It measures operational budgets, not peak capacity or leak freedom. A 24-hour soak remains a later Beta gate.

The 494 resource records include 493 complete samples and one planned restart sampling gap. There are zero unexpected sampling errors. The peak across all available RSS readings is 36,248 KiB; per-generation tables exclude the incomplete planned-restart sample.
