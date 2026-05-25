# Invariants

These rules define Daylily's shape. Do not break them without an ADR.

## Architecture

1. `DaylilyCore` is runtime-only and transport-free.
2. `DaylilyCore` must not import NIO modules.
3. User-facing APIs must not expose NIO types.
4. Runtime APIs are the ground truth.
5. Macros lower into runtime APIs.
6. Transport adapters call `Application.respond(to:)` or an equivalent runtime responder.

## Developer Experience

1. `swift build` must pass.
2. `swift run` must start the example server.
3. `swift run HelloDaylily --check` must pass.
4. If server behavior changes, smoke test with `curl`.
5. Every public API change must update AIDEV.

## Public API

1. Public closures should be `@Sendable`.
2. Public runtime types should be `Sendable` when practical.
3. `Request` and `Response` are Daylily-owned types.
4. `String`, `Status`, and `Response` remain simple return values.
5. New return types should conform to `ResponseConvertible`.

## Routing

1. Paths normalize to leading slash.
2. `:name` is the current path parameter syntax.
3. Literal routes beat parameter routes.
4. Parameter routes beat wildcard routes.
5. Group prefixing must not create duplicate slashes.

## AIDEV

1. AIDEV is the AI handoff contract.
2. AIDEV should be enough to understand the project without reading source first.
3. If implementation and AIDEV disagree, the task must reconcile the mismatch.
4. New modules, public APIs, commands, or workflows must be reflected in AIDEV.
5. `registry.yml` should remain machine-readable and reasonably complete.

