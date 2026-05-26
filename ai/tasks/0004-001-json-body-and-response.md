# 0004-001 JSON Body and Response

Status: implemented
Epic: 0004-json-system

Steps:

- [x] 0004-001.1 Add JSON body decoding and response helpers.

## Goal

Add the first JSON capability without pulling Foundation into `DaylilyCore`.

Target user shape:

```swift
Post("/json/echo") { request in
    let input = try request.json(EchoPayload.self)
    return JSON(EchoResponse(echo: input.message))
}
```

## Scope

- Add a `DaylilyJSON` module.
- Re-export `DaylilyJSON` from `Daylily`.
- Add `Request.json(_:)` for buffered JSON body decoding.
- Add `JSON<Value>` as an explicit response wrapper.
- Add example JSON routes.
- Add behavior checks for JSON response, JSON request body, and invalid JSON.
- Update README and AIDEV.

## Non-Goals

- Streaming JSON.
- Multipart.
- Request body size limits.
- Request content type enforcement.
- Custom encoder/decoder configuration.
- Automatic `Encodable` to `ResponseConvertible` conformance.
- `@Body` macro injection.

## Public API Impact

New product:

```swift
.library(name: "DaylilyJSON", targets: ["DaylilyJSON"])
```

New public response wrapper:

```swift
public struct JSON<Value: Encodable & Sendable>: ResponseConvertible
```

New public request helper:

```swift
public extension Request {
    func json<Value: Decodable>(_ type: Value.Type) throws -> Value
}
```

`Daylily` now re-exports:

```swift
@_exported import DaylilyJSON
```

## AIDEV Updates Required

- `README.md`
- `README.zh-CN.md`
- `AIDEV.md`
- `ai/aidev/start-here.md`
- `ai/aidev/project-map.md`
- `ai/aidev/architecture.md`
- `ai/aidev/concepts.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/conventions.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/workflow.md`
- `ai/aidev/roadmap.md`
- `ai/aidev/registry.yml`
- `ai/prompts/daylily-agent.md`

## Validation

Required:

```sh
swift build
swift run HelloDaylily --check
```

Server smoke:

```sh
swift run
curl http://127.0.0.1:8080/json/health
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/json/echo
```

## Notes

- `DaylilyCore` remains transport-free and Foundation-free.
- Decode failures intentionally map to `400 Bad Request` with `Invalid JSON body`.
- JSON support remains explicit through `JSON(...)`; broad `Encodable` response conversion is deferred.
