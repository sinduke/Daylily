# Contract and AI change regression

Daylily provides two separate checks: deterministic API contract regression and
repeatable real AI application-edit trials. They answer different questions.

## OpenAPI compatibility direction

```sh
python3 scripts/openapi-compatibility-check.py old.json new.json
```

The direction is **an old generated client calling a new server**. Request values
accepted by the previous contract should still be accepted; new response values
must remain understandable by the previous client. Exit `0` means compatible
within the supported subset, `1` reports a breaking change, and `2` means invalid
or unsupported input. Unsupported input never produces a compatible result.
`--output result.json` saves the same structured result printed to stdout.

| Change | Request | Response |
| --- | --- | --- |
| Add required property | Breaking | Compatible for an open old object |
| Remove required guarantee | Compatible | Breaking |
| Narrow enum values | Breaking | Compatible |
| Expand enum values | Compatible | Breaking |
| Change type or format | Conservatively breaking | Conservatively breaking |
| Remove endpoint/method | Breaking | — |
| Add optional request parameter | Compatible | — |
| Add required request parameter | Breaking | — |

The subset is OpenAPI 3.1 JSON with inline operations/parameters/media definitions,
local schema references (including recursive object references), scalar types,
objects with explicit properties/required fields, arrays, scalar enums, and
boolean `additionalProperties`. It compares query/header/path/cookie parameters,
request bodies, response media and response statuses. A new endpoint is additive.
A newly emitted status without an old decoder/default response is breaking.
Response matching supports exact HTTP status codes (`100`–`599`) and `default`.
An explicit old response keeps its decoder even when a new `default` takes over
that status, so the new fallback must remain compatible with that old decoder.

This checks the declared fields used by generated clients, not arbitrary unknown
request properties sent through manually constructed JSON. In particular an
optional newly declared request property is considered additive. Closed-object
rules are checked explicitly, but this is not a proof of general JSON Schema set
inclusion. Type/format changes are conservative even when a numeric widening
could be safe for a specific client.

Composition (`oneOf`/`anyOf`/`allOf`), nullable/type unions, external references,
custom parameter serialization, validation bounds/patterns, security requirements,
callbacks/webhooks, response headers/links, and schema-valued additional properties
return unsupported. Response status ranges such as `2XX` also return unsupported.
Unused component schemas and informational annotations are
not wire-compatibility changes. Server URL routing, operationId/source symbol
changes, runtime authentication, and semantic business behavior are outside the
scope. This tool does not replace a full OpenAPI validator.

## Real generated client regression

```sh
python3 ai/evals/contracts/test_compatibility.py
scripts/contract-regression-test.sh --mode path
```

The shell command accepts the same exact `revision` and `release` dependency
selectors as other smoke scripts and records the resolved Daylily dependency.
`CONTRACT_PORT` defaults to `18085`; `--workdir` requires an empty directory and
`--keep` preserves generated code, schema diffs and resolver records.

The isolated SwiftPM consumer uses Swift OpenAPI Generator 1.13.1 to generate
three real modules from checked-in old, compatible-new and breaking-new schemas.
The old schema is derived from `examples/openapi-service`; that example remains
unchanged. Real localhost HTTP checks cover:

- Old generated client calling the compatible new server with GET and POST.
- New generated client sending a new optional request field and decoding a new
  required response field; narrowed response enum values remain understood.
- Old client rejected when the breaking new contract requires an additional
  request field; a client generated from that contract supplies it successfully.

The fixture application explicitly installs OpenAPIRuntime's
`ErrorHandlingMiddleware` when registering generated handlers so request decoding
errors become HTTP 400. This is application-owned error policy; the transport
alone does not promise to map every foreign error type.

## Real AI trials

See [the independent edit runner](../ai/evals/repeated-changes/README.md). Three
fixed tasks run twice from incomplete sources. The model edits actual files;
the harness runs immutable acceptance after each attempt. Per-attempt output
records acceptance, model/verification wall time, CLI token usage and unknown
cost. These account-consuming trials are intentionally excluded from automatic
CI; deterministic acceptance/reference checks can run in CI independently.

Six passing fixed examples provide local evidence for these tasks, not a general
success-rate estimate or performance/cost promise.
