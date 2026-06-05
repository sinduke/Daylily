# 0021-003 Swift HTTP Types Adapter

Status: implemented

Purpose:

- Make Daylily interoperate with Swift HTTP Types through an optional adapter.
- Preserve Daylily-owned request/response models while making the HTTP boundary lossless enough for future ecosystem integrations.
- Prepare the ground for the future Swift OpenAPI Generator Daylily transport.

Scope:

- Make the Daylily HTTP boundary lossless for custom method tokens, repeated headers, raw request targets, repeated query parameters, and HTTPTypes pseudo fields.
- Add optional `DaylilyHTTPTypes`.
- Convert between Daylily `Request`/`Response` and Swift HTTP Types `HTTPRequest`/`HTTPResponse`.
- Reject conversions that would require silent lossy header/status legalization.

Implemented:

- `HTTPMethod` is now an open token value that preserves custom valid method strings.
- `Headers` now stores ordered `HeaderField` values and supports repeated fields.
- `QueryParameters` now stores ordered `QueryParameter` values, repeated names, flag parameters, and the raw query string.
- `Request` now preserves `rawTarget` separately from parsed `path`, plus `scheme`, `authority`, and `extendedConnectProtocol`.
- `DaylilyNIO` preserves repeated inbound headers and no longer maps unknown valid methods to `GET`.
- `DaylilyHTTPTypes` adds `Request(httpTypesRequest:)`, `Request.httpTypesRequest()`, `Response(httpTypesResponse:)`, `Response.httpTypesResponse()`, and header field conversion helpers.
- External consumer smoke path mode imports and exercises `DaylilyHTTPTypes`.

Non-goals:

- Replacing Daylily `Request` or `Response`.
- Adding a new transport.
- Consuming or buffering `RequestBody` inside the adapter.
- Implementing Swift OpenAPI Generator transport.
- Re-exporting Swift HTTP Types from the umbrella `Daylily` module.

Validation:

- `swift test`
- `scripts/consumer-smoke-test.sh --mode path`
- `git diff --check`
