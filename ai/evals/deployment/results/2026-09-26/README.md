# Local Linux deployment evidence — 2026-09-26

The 300-second sustained phase passed with 31,382 successful requests and zero failures. See `results.json` for all measured scenarios, image identities, source hash and resource snapshots. The run used the working tree based on `f0d5342`, including the unreleased operational increment; it is **not** an alpha.2 tag test.

The compact committed evidence includes the original result, dependency lockfile, proxy config and pre-restart lifecycle log. `artifact-hashes.json` identifies all original files. Full build and per-container logs are retained at `/tmp/daylily-deployment-20260926` on the execution host; they are not embedded in this repository. Subsequent CI uploads its full artifact directory independently.

Since this run, the harness explicitly pulls the Swift base image before building so its image identity is inspectable on a clean BuildKit host. The application/runtime sources are unchanged; documentation files were added later, so a later whole-context hash differs. No production/overnight/throughput or leak-freedom claim is made.
