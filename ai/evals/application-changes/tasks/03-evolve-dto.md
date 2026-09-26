# 03 Change a DTO and its explicit schema

Starting point: `POST /books` decodes a `CreateBookInput` containing only `title`,
returns a `Book(id: 1, title: input.title)` as 201 JSON, and describes named
`CreateBookInput` and `Book` schemas with their existing required fields.

Request: add a required string `author` to both input and output DTOs. Preserve
title, ID, status, operation ID `createBook`, and route path. Update the explicitly
registered OpenAPI object properties and required arrays for both named schemas.
Decoding must reject a missing author or an author with a non-string JSON value.

Acceptance:

- Posting `{"title":"Swift","author":"Ada"}` returns 201 and a JSON book with
  ID 1, title `Swift`, and author `Ada`.
- A missing author and numeric author each return 400.
- Validated OpenAPI references `CreateBookInput` in the request and `Book` in the
  201 response; both encoded component schemas define required string `author`.

Completed reference: `Sources/ApplicationExercises/EvolveDTO.swift`.
Executable checks: `EvolveDTOAcceptance` (2 tests).
