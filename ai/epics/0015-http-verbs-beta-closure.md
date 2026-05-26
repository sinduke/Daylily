# 0015 HTTP Verbs Beta Closure

Status: in-progress

Purpose:

- Make Daylily's beta HTTP surface feel complete enough for normal JSON API work.
- Close the gap between runtime DSL, testing helpers, macro syntax, and OpenAPI output for common HTTP verbs.

Recommended tasks:

- `0015-001-runtime-and-testing-http-verbs` (implemented)
- `0015-002-macro-and-openapi-http-verbs`

Design notes:

- `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, and `OPTIONS` should be first-class route methods.
- Runtime support comes before macro sugar.
- `HEAD` and `OPTIONS` are explicit route methods in the first beta slice.
- Do not add implicit `HEAD -> GET` fallback in the first beta slice.
- Do not add automatic `OPTIONS Allow` responses in the first beta slice.
- `DELETE` examples should use `Status.noContent` when no body is needed.

Non-goals for this epic:

- Full HTTP method registry.
- Automatic CORS preflight behavior.
- Automatic `OPTIONS` route generation.
- Automatic `HEAD` fallback to `GET`.
- Method override headers.
