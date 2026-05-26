# 0009-002 Explicit Buffered Body Helper

Status: implemented
Epic: 0009-middleware-system

Goal:

- Add an explicit helper for middleware and handlers that intentionally need to inspect a request body and pass an equivalent body downstream.
- Make buffering visible in the API name and require a clear body size limit.
- Preserve Daylily's one-shot `Body` model.

Scope:

- Add `Request.with(body:)`.
- Add `Request.withBufferedBody(upTo:_:)`.
- Keep the helper in `DaylilyCore` for the first version.
- Collect the current body into memory under an explicit `ByteCount` limit.
- Create a new `Body.bytes(...)` for the returned/replayed request.
- Return both the replacement request and collected bytes to the caller's closure.
- Preserve existing `BodyError.tooLarge -> 413 Payload Too Large` semantics.
- Add checks covering replacement, downstream reads, one-shot behavior, and limit errors.
- Update AIDEV documentation and README examples if needed.

Non-goals:

- Automatic body replay.
- Hidden middleware buffering.
- File-backed buffering.
- Multipart parsing.
- JSON/Content abstraction.
- Streaming replay.
- Transport changes.
- Macro sugar.

Steps:

- [x] 0009-002.1 Add `Request.with(body:)`.
- [x] 0009-002.2 Add `Request.withBufferedBody(upTo:_:)` in `DaylilyCore`.
- [x] 0009-002.3 Ensure the replacement body is still one-shot.
- [x] 0009-002.4 Add checks for middleware-style inspection plus downstream body reading.
- [x] 0009-002.5 Add checks for body size limit and 413 mapping.
- [x] 0009-002.6 Update AIDEV docs, registry, and README examples if useful.
- [x] 0009-002.7 Review, fix, validate, then finish the task.

Architecture impact:

- The helper belongs in `DaylilyCore` for now because it operates only on `Request`, `Body`, and `ByteCount`.
- `DaylilyJSON` and future Content APIs may later wrap or relocate higher-level body helpers.
- `DaylilyCore` must remain transport-free and must not import NIO or Foundation for this helper.
- No transport API should change.

Public API impact:

Target API:

```swift
public extension Request {
    func with(body: Body) -> Request

    func withBufferedBody<R: Sendable>(
        upTo limit: ByteCount,
        _ operation: @Sendable (Request, [UInt8]) async throws -> R
    ) async throws -> R
}
```

Target usage:

```swift
struct WebhookSignature: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        try await request.withBufferedBody(upTo: .megabytes(1)) { replayedRequest, bytes in
            try verify(bytes, headers: request.headers)
            return try await next.respond(to: replayedRequest)
        }
    }
}
```

Naming decision:

- Use `withBufferedBody`.
- Do not use `replayBody` as the primary name because it hides the important fact that memory buffering happens.

Semantics:

- `withBufferedBody` consumes the original request body.
- It creates a new request with `Body.bytes(collectedBytes)`.
- The new body remains one-shot.
- The closure receives:
  - the request containing the replacement body
  - the collected bytes for signature checks, logging, auditing, or other inspection
- If the collected body exceeds `upTo`, the helper throws `BodyError.tooLarge`.
- `Application.respond(to:)` should continue to render `BodyError.tooLarge` as `413 Payload Too Large`.
- The helper does not allow downstream code to read the same body repeatedly.
- The helper does not enable automatic middleware replay.

Body policy:

- `Body` remains one-shot.
- Explicit buffering is allowed when the user asks for it by calling `withBufferedBody`.
- Hidden buffering is not allowed.
- Any future file-backed or streaming replay design must be a separate task.

AIDEV updates required:

- `ai/aidev/runtime-contracts.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/concepts.md`
- `ai/aidev/conventions.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `README.md`
- `README.zh-CN.md`

Validation:

Required after implementation:

```sh
swift build
swift run HelloDaylily --check
```

Suggested checks:

- `Request.with(body:)` replaces the body while preserving method, path, headers, and parameters.
- `withBufferedBody(upTo:_:)` gives the closure collected bytes.
- The replayed request can be passed to `next`.
- Downstream code can read the replacement body once.
- A second read of the replacement body fails with `BodyError.alreadyConsumed`.
- Exceeding the limit throws `BodyError.tooLarge`.
- A route or middleware using the helper maps over-limit bodies to `413 Payload Too Large`.

Completed validation:

- `swift build`
- `swift run HelloDaylily --check`
- `registry.yml` YAML parse check
- `git diff --check`

Notes:

- This task exists because middleware can read body, but reading a one-shot stream consumes it.
- The helper is a deliberate escape hatch, not a change to Daylily's body model.
- The API should make memory buffering obvious to both humans and AI agents.
