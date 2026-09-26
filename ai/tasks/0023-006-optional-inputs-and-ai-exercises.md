# 0023-006 Optional Inputs and AI Exercises

Status: implemented
Epic: 0023-reliability-and-streaming

Goal:

- Make optional query/header handlers agree with runtime extraction and OpenAPI metadata.
- Supply reproducible application exercises for adding a route, replacing a dependency, and changing a DTO.

Scope:

- Optional query/header macro lowering; missing values are nil and invalid present values remain 400.
- Compile-time rejection of optional path inputs.
- Checked examples, acceptance tests, and an AI handoff recipe.

Non-goals:

- Optional path segments, automatic default argument decoding, or a claim that fixtures measure autonomous agent success.

Steps:

- [x] 0023-006.1 Extend input wrappers and macro lowering.
- [x] 0023-006.2 Add behavioral, metadata, external compile, and diagnostic validation.
- [x] 0023-006.3 Add runnable application exercises and synchronize docs.

Architecture impact:

- Macros use existing runtime get(_:as:), with metadata for the wrapped scalar type.

Public API impact:

- Query and Header wrappers accept optional Sendable values.

AIDEV updates required:

- API registry, runtime contracts, registry, examples and capability matrix.

Validation:

- swift test, external consumer smoke, negative macro compilation and exercise acceptance checks.

Integration note: implementation, local review, and shared API documentation are complete. The remote exact-candidate release gate is tracked by 0023-007.

Validation: current external macro consumer passed with T?, Optional<T>, Swift.Optional<T>, missing/present/invalid HTTP inputs, and expected optional-path compilation failure. Six application exercise tests and runtime/schema optional semantics passed on 2026-09-26.
