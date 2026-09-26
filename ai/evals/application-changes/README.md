# Application change exercises

These are three fixed application tasks implemented from the Daylily development
contract. Each task records its starting point, requested change, and observable
acceptance criteria. The Swift source is the completed reference result; six
Swift Testing checks execute those criteria against Daylily's in-memory client.

| Task | Reference result | Acceptance suite |
| --- | --- | --- |
| [01 Add an endpoint](tasks/01-add-endpoint.md) | `Sources/ApplicationExercises/AddEndpoint.swift` | `AddEndpointAcceptance` |
| [02 Replace a dependency](tasks/02-replace-dependency.md) | `Sources/ApplicationExercises/ReplaceDependency.swift` | `ReplaceDependencyAcceptance` |
| [03 Evolve a DTO and schema](tasks/03-evolve-dto.md) | `Sources/ApplicationExercises/EvolveDTO.swift` | `EvolveDTOAcceptance` |

Read the repository's `AIDEV.md`, then `ai/aidev/runtime-contracts.md` and
`ai/aidev/api-registry.md` before attempting a task. Use runtime APIs; no macro,
transport, framework-internal, or test-expectation edits are needed.

Run from the repository root:

```sh
scripts/ai-exercises-smoke-test.sh --mode path
```

The smoke script copies only the exercise manifest, source, and tests into a fresh
external SwiftPM package and resolves the local Daylily checkout. Use `--keep`
and `--workdir /new/path` to inspect `Package.resolved`, `dependency-record.json`,
and the compiled consumer. On macOS, select a full Xcode toolchain if the Command
Line Tools installation cannot import `Testing`:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer scripts/ai-exercises-smoke-test.sh --keep
```

For a manual attempt, keep the fixed criteria and tests, replace the corresponding
reference implementation with the starting point described in that task, and
implement the requested change. The reference source allows a later attempt to
compare its result with this completed run.

These checks establish only that the three supplied implementations satisfy these
specific tasks. They do not measure general AI capability, success rate, latency,
or cost. They use `TestClient`; real HTTP interoperability is separately tested by
`scripts/openapi-smoke-test.sh`.
