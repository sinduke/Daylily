# Alpha.4 publication verification

[Published prerelease](https://github.com/sinduke/Daylily/releases/tag/0.1.0-alpha.4), not a draft.

Preparation: [12/12 jobs](https://github.com/sinduke/Daylily/actions/runs/36249744913) passed before publication. Twelve exact-revision resolver pins and ten expected dependency records matched the release commit.

Exact-tag verification: [14/14 jobs](https://github.com/sinduke/Daylily/actions/runs/36250605916).
Published revision: `7fc09c4289052355578f007f4ebfb97c9b686430`

14/14 jobs passed. All 12 expected Daylily resolver pins match the exact candidate and version `0.1.0-alpha.4`.
Ten expected dependency-record files agree; OpenAPI emits Package.resolved only. Four historical alpha.1 pins are unchanged.

Both platforms: 74 Swift tests / 7 suites, 35 compatibility tests, 13 TCP harness tests, 3 baseline-only fixtures without model calls, and 2 persistent consumer tests. The path, revision and release suites on each platform pass 8 public-consumer tests and 10 generated-client HTTP groups.

## Resolver pins

| Path | Version | Revision |
| --- | --- | --- |
| `validation-macOS-release/consumer/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `validation-macOS-release/template/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `validation-macOS-release/commerce/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `validation-macOS-release/openapi/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `validation-macOS-release/contract/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `persistent-consumer-macOS/persistent-consumer/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `validation-Linux-release/consumer/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `validation-Linux-release/template/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `validation-Linux-release/commerce/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `validation-Linux-release/openapi/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `validation-Linux-release/contract/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |
| `persistent-consumer-Linux/persistent-consumer/Package.resolved` | 0.1.0-alpha.4 | `7fc09c4289052355578f007f4ebfb97c9b686430` |

## Deployment evidence

- deployment-Linux: 30.010 s, 3960 successful requests, zero unexpected failures and cleanup errors.
- sustained-business-Linux: 60.122 s, 3192 successful requests, 20 expected database 503s, zero unexpected failures and cleanup errors.

The sustained-business traffic counts, allowed outage responses, source/harness/image/TLS provenance, dependency pins and per-generation resource budgets were independently checked against the downloaded raw artifacts. This is a short release smoke; the previously completed one-hour run remains separate historical acceptance evidence.

No mismatched pins, missing required checks or failed jobs found. Raw artifacts are available from the linked CI runs; the local audit also retains full core logs and SHA256SUMS inventories.

## Evidence provenance

The annotated alpha.4 tag targets the published revision above. Prior alpha.1/2/3 tag objects and revisions are unchanged. Sources, tests, scripts, CI, root package manifest/lock and examples are unchanged from accepted runtime `1f8e0ea5f149b09cc398d302bf37c5cd63258452`; release preparation only updates documentation, registry and the minimal template dependency version. Publication closure adds documentation and registry evidence only.

The [one-hour acceptance](alpha4-acceptance-results.md) retains its original SHA and measurements. This release-time smoke is separate; it does not represent a repeated one-hour run or the later 24-hour Beta gate.

The independent audit inventories preserve these SHA-256 digests (raw artifacts plus fetched logs/metadata):

| Audit | Files in inventory | Inventory SHA-256 |
| --- | ---: | --- |
| Preparation | 162 | `d6ca800b77ecd013cd6a2331261ee8e2e5d2accbc51af69f5cf30e1dfd19f091` |
| Exact tag | 205 | `0f337e39769717675d937cd6fd75e305d331537a6cf9fb28a3be4064a206e5c5` |

The root agent separately checked all twelve release lock files and ten expected records. OpenAPI intentionally emits only Package.resolved. Both audits found no mismatched version or revision.
