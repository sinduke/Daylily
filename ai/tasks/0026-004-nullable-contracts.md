# 0026-004 Nullable Contracts

Status: implemented
Epic: 0026-real-business-and-sustained-operation

Goal:

- Author explicit OpenAPI 3.1 nullability without conflating absent properties and JSON null.
- Compare old-client to new-server contracts directionally, including enums and references.
- Validate generated old/new clients over real HTTP, including expected breaking behavior.

Scope:

- One concrete schema type plus null; existing schema APIs remain source compatible.
- Local references to nullable components; arbitrary unions/composition remain unsupported.
- Python compatibility fixtures, Swift schema tests and generated HTTP regression.

Non-goals:

- Arbitrary type unions/composition, deep Swift reflection, a general JSON Schema validator, or generated Swift tri-state patch properties.
- Patching the upstream Swift OpenAPI Generator; downstream generator limitations remain explicit.

Steps:

- [x] Add explicit nullable schema authoring, encoding/decoding and validation.
- [x] Extend compatibility checks for nullability and required/enum intersections.
- [x] Exercise compatible and breaking generated clients against live HTTP handlers.
- [x] Record focused verification and hand shared documentation changes to integration owner.

Architecture impact:

- No Core, macro, transport or persistence changes. Schemas remain explicitly authored.

Public API impact:

- `OpenAPISchema.nullable() -> Self` includes null beside one concrete type; string enums also include a literal null member. Existing initializers/builders remain unchanged.
- Read-only `OpenAPISchema.isNullable: Bool` describes null acceptance by a concrete schema, including enum intersection; it does not resolve references.
- Encoding uses OpenAPI 3.1 `type: [T, "null"]`. Decoding accepts either order, preserves an enum that excludes null, and rejects arbitrary or duplicate type unions.
- Presence remains independent: the parent object's `required` list controls whether a key must exist; `.nullable()` controls allowed values when present. An optional non-null key may be absent but its declared schema still rejects explicit null.
- Nullable reference wrappers are rejected by both `validate()` and encoding: `$ref` siblings cannot widen the referenced schema to accept null. Mark the component itself nullable instead. OpenAPI 3.0 nullable type arrays fail validation.
- The Python checker adds `request-null-removed` / `response-null-added` and null-only-versus-concrete findings. It intersects scalar enum values with their declared type, follows local references, and preserves unsupported exit 2 for general unions/composition, `nullable: true` (3.0 spelling), unknown keywords, reference siblings and unsupported constraints. Empty enum/type intersections remain unsupported.

AIDEV updates required:

- Parent owns shared API/runtime registry and user docs. This slice records the exact contract here.

Validation:

- Focused Swift OpenAPI schema suite, Python directional cases, actual generated client/server HTTP regression.
- Official references: https://spec.openapis.org/oas/v3.1.0.html and https://json-schema.org/understanding-json-schema/reference/null .

Notes:

- No commits/pushes by this slice. Shared AIDEV/docs/registry and exact-candidate CI remain parent-owned integration work.
- Swift OpenAPI Generator 1.13.1 loses nullable array-item semantics when items are `$ref` to a nullable scalar component: observed generated `NullableText = Swift.String` with `notes: [NullableText]`, causing `[nil]` consumer code to fail compilation. The initial log is retained at `/tmp/daylily-alpha4-nullable-contract.log`. Reproduce by replacing `NotesInput.properties.notes.items` in `nullable-old.json`/`nullable-compatible.json` (and the nullable breaking response items) with `{"$ref":"#/components/schemas/NullableText"}` and running the contract script.
- Final generated HTTP fixtures use inline nullable array items. Nullable component refs are still covered in the schema/compatibility tests and optional generated properties; do not claim that all upstream generated reference shapes preserve nullability.
- Generated Swift Codable optional properties may collapse absent and explicit null. No new tri-state Swift value or universal generated required-nullable presence validator is promised. The HTTP fixture tests both raw wire forms for optional fields, plus separate missing/null rejection for a required non-null array.

Verification — 2026-09-26:

- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test --scratch-path /tmp/daylily-alpha4-nullable-tests --jobs 2 --filter OpenAPISchemaTests`: 9 tests passed. An earlier concurrent build was interrupted by another agent editing ResourceBoundTests.swift; the stable incremental rerun passed. Final log `/tmp/daylily-alpha4-nullable-tests-rerun.log`.
- `python3 ai/evals/contracts/test_compatibility.py`: 35 methods passed. Nullable additions include a 32-case presence/nullability direction matrix and 72 enum/null-intersection comparisons.
- Explicit CLI verification: compatible fixture exit 0, breaking-nullable fixture exit 1 with both directional findings, general union exit 2 with `compatible: null`.
- Six generated modules compiled with Swift 6.3.2 and OpenAPI Generator 1.13.1. Actual HTTP executable passed all 10 PASS groups (the prior 4 and 6 nullable groups), including explicit array null transmission, optional absent/null/value, required array absence/null HTTP 400, narrowed request null HTTP 400, and expanded response null causing HTTP-200-body DecodingError in the old client. Logs `/tmp/daylily-alpha4-nullable-contract-rerun.log`, `/tmp/daylily-alpha4-nullable-http.log`.
- `bash -n scripts/contract-regression-test.sh` and scoped `git diff --check` passed.
- Final complete clean-package command `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer SMOKE_JOBS=2 CONTRACT_PORT=18089 scripts/contract-regression-test.sh --mode path --workdir /tmp/daylily-alpha4-nullable-contract-final --keep` exited 0: all 35 Python methods, supported compatible/breaking diffs, six generated modules and all 10 real HTTP PASS groups succeeded. Log `/tmp/daylily-alpha4-nullable-contract-final.log`; resolver/schema-diff artifacts are in that workdir. Its dependency record honestly identifies base revision `8cea3604abff126105e3759ccfa6b13481b0be32` with working-tree changes; exact committed candidate CI belongs to 0026-006.

Independent review of 0026-002:

- No blocking issue found in the bounded dispatcher/write-deadline implementation. Admission increments the server-wide counter under a lock before creating a task, eliminating waiting-task accumulation. Write timer and completion execute on the same event loop; completion cancels its timer, timeout records failed before connection close, and producer idle time is excluded. Saturation/recovery/shutdown and stalled/disabled/idle-producer tests address the principal failure modes. This review did not modify that task's files or replace its recorded execution evidence.
