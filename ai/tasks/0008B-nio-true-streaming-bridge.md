# 0008B NIO True Streaming Bridge

Status: implemented

## Goal

Replace the temporary buffered NIO request body bridge with a true streaming bridge from NIO HTTP request chunks into Daylily `Body`.

This task depends on 0008A.

## Scope

- Create the Daylily `Request` after NIO receives the HTTP request head.
- Start the route handler before the entire request body is buffered.
- Feed each NIO body chunk into Daylily `BodyBytes`.
- Finish the body stream when NIO receives `.end`.
- Fail the body stream on channel or protocol errors.
- Preserve Daylily public API boundaries.
- Add bounded buffering.
- Define and implement cancellation behavior.
- Define and implement practical backpressure behavior.
- Add chunked upload smoke checks.

## Non-goals

- Public exposure of NIO types.
- Response body streaming.
- Multipart parsing.
- Upload-to-file helpers.
- HTTP/2.
- TLS.
- Middleware body replay.
- OpenAPI body metadata.

## Dependency

0008A must exist first:

- `Request.body: Body`
- `BodyBytes: AsyncSequence<ByteChunk>`
- one-shot body consumption
- `BodyError`
- `ByteCount`
- async JSON body helpers

0008B should not redesign those public APIs unless review finds a serious flaw.

0008B was implemented without changing normal user-facing body APIs. The only new construction/writer surface is transport SPI:

```swift
@_spi(Transport) Body.stream(bufferLimit:)
@_spi(Transport) BodyStream
@_spi(Transport) BodyStreamWriter
```

## Architecture Impact

`DaylilyNIO` changes from:

```text
head -> buffer all body chunks -> end -> create Request -> call handler
```

to:

```text
head -> create Request with streaming Body -> call handler
body chunk -> feed Body stream
end -> finish Body stream
error -> fail Body stream
```

`DaylilyCore` should not import NIO.

`Daylily` user handlers should continue to read:

```swift
for try await chunk in request.body.bytes {
    ...
}
```

not:

```swift
ByteBuffer
HTTPServerRequestPart
ChannelHandlerContext
```

## Public API Impact

Ideally none beyond 0008A.

0008B should make the existing `Body` model truly streamed when the transport supports streaming.

If implementation reveals missing hooks, update 0008A/0008B docs before changing public API.

Implemented hook:

- `Body.stream(bufferLimit:)` is exposed through `@_spi(Transport)` for `DaylilyNIO`.
- The normal public user API remains `request.body.bytes`, `collect(upTo:)`, `string(upTo:)`, and JSON helpers.

## Backpressure Rules

Do not use unbounded buffering as the final design.

The bridge needs bounded buffering between NIO and Daylily body consumption.

Requirements:

- A slow handler must not let memory grow without bound.
- A fast handler should receive chunks in request order.
- Cancellation should stop or drain the body deliberately.
- Producer failure should surface as `BodyError.streamFailed`.
- End of request should finish the stream cleanly.

Implementation options to evaluate in build mode:

- Daylily-owned bounded async byte channel: selected.
- NIO `autoRead` control: selected.
- High-water and low-water buffering thresholds: deferred beyond the initial bounded writer model.

## Cancellation Rules

Cases to handle:

- Handler returns before reading the whole body.
- Handler throws before reading the whole body.
- Client closes the connection while handler reads.
- Server task is cancelled while body chunks are still arriving.

Expected behavior:

- The body stream should finish or fail exactly once.
- Pending body consumers should unblock.
- Transport resources should be released.
- No public NIO types should leak.

Implemented behavior:

- `finish()` ends async iteration cleanly.
- `fail()` resumes pending consumers with `BodyError.streamFailed`.
- `cancel()` clears buffered chunks and unblocks pending consumers without surfacing a transport error.
- If a handler returns before a body-bearing request ends, `DaylilyNIO` cancels the body stream and closes the response connection instead of keeping the connection alive.
- Client close and channel errors fail the body stream.

## Error Mapping

Use 0008A `BodyError` mapping:

```text
BodyError.streamFailed -> 400 Bad Request, "Request body stream failed"
BodyError.tooLarge     -> 413 Payload Too Large, "Request body too large"
```

If NIO errors need internal logging, keep logging transport-local and do not expose raw error descriptions in default responses.

## Checks Required

In-process checks:

- Streaming body yields chunks in order.
- Stream finish terminates async iteration.
- Stream failure throws `BodyError.streamFailed`.
- Cancellation unblocks readers.

Server smoke:

- POST `/echo` with regular body still works.
- POST `/json/echo` still works.
- Chunked request can be read through `request.body.bytes`.
- Large body over the configured route/helper limit returns 413.

Suggested manual smoke:

```sh
curl -X POST --http1.1 -H 'transfer-encoding: chunked' --data-binary @large-file http://127.0.0.1:8080/upload/count
```

CI:

```sh
swift build
swift run HelloDaylily --check
```

Completed validation:

- `swift build`
- `swift run HelloDaylily --check`
- `registry.yml` YAML parse check
- `git diff --check`
- Server smoke:
  - `GET /hello` returned `200 OK`
  - `POST /echo` with regular body returned `200 OK`
  - `POST /json/echo` returned `200 OK`
  - chunked `POST /upload/count` returned `{"bytes":6,"chunks":1}`
  - 70 KB `POST /echo` returned `413 Payload Too Large`

## AIDEV Updates Required

- `ai/aidev/architecture.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `README.md`
- `README.zh-CN.md`

## Notes

- 0008B is the transport-hard part.
- 0008B started after 0008A was implemented and reviewed through build/check/smoke.
- Backpressure is implemented with bounded `BodyStreamStorage` buffering plus NIO `autoRead` pause/resume.
- Response body streaming, multipart, upload-to-file helpers, and richer server configuration remain future work.
