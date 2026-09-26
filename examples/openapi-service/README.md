# Daylily OpenAPI service

This package actually generates both server and client Swift code with Apple's
`OpenAPIGenerator` plugin. There are no handwritten generated stubs.

```sh
swift run ExportSchema Sources/GeneratedAPI/openapi.json
swift run App --check
```

`ExportSchema` validates a Daylily route-metadata contract with explicit schemas.
The build plugin generates the types, server registration, and client. `App
--check` creates an application-owned SwiftLog logger and ServiceGroup, serves
the generated API through Daylily, calls it using the generated client and the
URLSession transport, and verifies one ordered startup/shutdown/cleanup lifecycle.
`swift run App` keeps serving.

GET `/api/greetings/Swift` returns a typed greeting with string enum labels.
POST `/api/echo` accepts `{"message":"hello"}` and returns a typed JSON response.
The default address is `127.0.0.1:18083`; change `OPENAPI_PORT` if needed.

`openapi.json` is checked in for review. Regenerate it with `ExportSchema` after
changing its contract. The Swift output lives in SwiftPM's `.build` plugin output,
and the pinned generator version is reproducible from `Package.swift`.

From the Daylily repository root, `scripts/openapi-smoke-test.sh --mode path`
performs the same export, generation, and HTTP check in an isolated consumer and
fails if the checked-in specification differs from the exported contract.
Use `--keep` to inspect the generated code. See
[`docs/examples/openapi-transport.md`](../../docs/examples/openapi-transport.md)
for schema APIs and exact revision/release smoke modes.
