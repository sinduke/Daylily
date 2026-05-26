# 0016-001 Formal Test Target

Status: implemented

Goal:

- Add a formal SwiftPM test target for Daylily.
- Keep `swift run HelloDaylily --check` working.
- Avoid duplicating the behavior suite between executable checks and formal tests.

Scope:

- Add `Tests/DaylilyTests`.
- Use Swift Testing, not XCTest.
- Move shared behavior checks into an internal `DaylilyCheckSuite` target.
- Let `HelloDaylily --check` delegate to `DaylilyCheckSuite`.
- Add a focused formal test that uses `DaylilyTesting` without opening a port.
- Add `swift test` to CI and AIDEV validation commands.

Non-goals:

- Splitting every existing behavior check into separate fine-grained tests.
- Removing `swift run HelloDaylily --check`.
- Adding an external `swift-testing` package dependency.
- Changing runtime behavior.
- Changing public Daylily library APIs.

Rules:

- `DaylilyTesting` remains transport-free and NIO-free.
- `DaylilyCheckSuite` may depend on `Daylily`, `DaylilyCore`, and `DaylilyTesting`.
- Formal tests must not require a listening server port.
- Swift Testing should come from the selected Xcode toolchain.
- If Command Line Tools cannot locate `Testing`, local validation may use `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`.

Steps:

- [x] 0016-001.1 Add shared `DaylilyCheckSuite` target.
- [x] 0016-001.2 Add `DaylilyTests` Swift Testing target.
- [x] 0016-001.3 Preserve `HelloDaylily --check`.
- [x] 0016-001.4 Add `swift test` to CI.
- [x] 0016-001.5 Update README and AIDEV docs.
- [x] 0016-001.6 Review, fix, validate, then finish the task.

Architecture impact:

- Adds an internal check-suite target used by both executable checks and formal tests.
- Adds a formal test target under `Tests/DaylilyTests`.
- Keeps runtime modules unchanged.

Validation:

Required after implementation:

```sh
swift build
swift test
swift run HelloDaylily --check
```

Local toolchain note:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test
```

Completed validation:

```sh
swift build
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test
swift run HelloDaylily --check
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
```

Notes:

- The active local `xcode-select` path points at Command Line Tools, which cannot locate the built-in Swift Testing module.
- Opening the Xcode app is not required; using the installed Xcode developer directory is enough.
- An external `swift-testing` package dependency was tested and rejected because it is unnecessary with the Xcode toolchain and can conflict with the package's existing macro dependencies.
