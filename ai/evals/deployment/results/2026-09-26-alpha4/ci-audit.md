# Alpha.4 complete CI artifact audit

Run: https://github.com/sinduke/Daylily/actions/runs/36244501153
Candidate: `1f8e0ea5f149b09cc398d302bf37c5cd63258452`

## Jobs

| Job | Conclusion | Job ID |
| --- | --- | --- |
| Linux · sustained persistent business | success | 108411050234 |
| Linux · reverse-proxy deployment | success | 108411050378 |
| macOS · Swift 6.3.2 · path | success | 108411050395 |
| macOS · persistent commerce consumer | success | 108411050401 |
| Linux · persistent commerce consumer | success | 108411050404 |
| Linux · Swift 6.3.2 · core | success | 108411050409 |
| Linux · Swift 6.3.2 · path | success | 108411050447 |
| macOS · Swift 6.3.2 · legacy | success | 108411050464 |
| macOS · Swift 6.3.2 · revision | success | 108411050469 |
| Linux · Swift 6.3.2 · revision | success | 108411050511 |
| Linux · Swift 6.3.2 · legacy | success | 108411050526 |
| macOS · Swift 6.3.2 · core | success | 108411050568 |

## Resolver pins

| Artifact path | Version | Revision |
| --- | --- | --- |
| `validation-macOS-revision/consumer/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-macOS-revision/template/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-macOS-revision/commerce/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-macOS-revision/openapi/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-macOS-revision/contract/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `persistent-consumer-macOS/persistent-consumer/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-macOS-legacy/consumer/Package.resolved` | 0.1.0-alpha.1 | `5e4537770f0eedd8f96eb3eea04aaccd235a5707` |
| `validation-macOS-legacy/template/Package.resolved` | 0.1.0-alpha.1 | `5e4537770f0eedd8f96eb3eea04aaccd235a5707` |
| `validation-Linux-revision/consumer/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-Linux-revision/template/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-Linux-revision/commerce/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-Linux-revision/openapi/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-Linux-revision/contract/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `persistent-consumer-Linux/persistent-consumer/Package.resolved` | revision | `1f8e0ea5f149b09cc398d302bf37c5cd63258452` |
| `validation-Linux-legacy/consumer/Package.resolved` | 0.1.0-alpha.1 | `5e4537770f0eedd8f96eb3eea04aaccd235a5707` |
| `validation-Linux-legacy/template/Package.resolved` | 0.1.0-alpha.1 | `5e4537770f0eedd8f96eb3eea04aaccd235a5707` |

Exact-candidate resolver count: 12/12. Legacy alpha.1 resolver count: 4/4.

## Core and AI baseline evidence

Both persistent-consumer artifacts contain all three expected files: Package.resolved, dependency-record.json, and persistent-consumer.log.
- macOS persistent consumer: isolated executable build and 2 unit tests passed; `persistent-consumer-macOS/persistent-consumer.log`.
- Linux persistent consumer: isolated executable build and 2 unit tests passed; `persistent-consumer-Linux/persistent-consumer.log`.
- macOS: baseline-only 3/3; model not invoked; unchanged published alpha.3 archive. `validation-macOS-core/ai-baselines/summary.json`
- macOS: Swift 74 tests/7 suites and Python 35 compatibility + 13 HTTP regression tests. `core-macOS.log`
- Linux: baseline-only 3/3; model not invoked; unchanged published alpha.3 archive. `validation-Linux-core/ai-baselines/summary.json`
- Linux: Swift 74 tests/7 suites and Python 35 compatibility + 13 HTTP regression tests. `core-Linux.log`

## Generated-client HTTP contracts

- macOS path: 10/10 HTTP check groups; `validation-macOS-path/contract.log`
- macOS revision: 10/10 HTTP check groups; `validation-macOS-revision/contract.log`
- Linux path: 10/10 HTTP check groups; `validation-Linux-path/contract.log`
- Linux revision: 10/10 HTTP check groups; `validation-Linux-revision/contract.log`

## Sustained business cross-check

- Parent independently recomputed the 60.162-second short trial: 3,214 successful traffic rows, 20 expected database-unavailable rows, zero unexpected failures; 38 resource samples; source tree, executed harness, image, TLS root and cleanup checks passed.
- Parent audit source: `/tmp/daylily-alpha4-short-evidence-audit.json`; preserved copy: `parent-short-evidence-audit.json`. This is separate from the one-hour acceptance gate.

## Findings

No mismatched pins, missing expected checks, or failed jobs found.

## Evidence integrity

Files hashed: 160.
SHA256SUMS: [retained artifact hashes](ci-artifact-hashes.md)
Manifest SHA-256: `91fb90df1c2d2c68f72c09307435d61caacea3c59f1145de83969e5aa86b277b`

The 60-second business job in this run is not the separate one-hour acceptance run. Full business time-series/source-tree audit is owned by the parent agent.

Full job logs and artifact downloads are available from the run link above. Local audit copies are temporary working evidence; this report and the hash manifest preserve the verified findings. One-hour acceptance is recorded separately.
