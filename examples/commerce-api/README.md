# Daylily Commerce API Example

This is Daylily's first real API example: a small product and order service with
state, JSON DTOs, typed path/query inputs, route metadata, and transport-free
tests.

The shape intentionally stays close to `templates/minimal-app`:

```text
DaylilyCommerceAPI/
├── Package.swift
├── Sources/
│   ├── App/
│   │   └── main.swift
│   └── AppCore/
│       └── App.swift
└── Tests/
    └── AppCoreTests/
        └── AppCoreTests.swift
```

## Run It

From this directory:

```sh
swift build
swift test
swift run App --check
swift run App
```

The server listens on:

```text
http://127.0.0.1:8080
```

Try it:

```sh
curl http://127.0.0.1:8080/api/health
curl http://127.0.0.1:8080/api/products
curl 'http://127.0.0.1:8080/api/products?category=tea'
curl http://127.0.0.1:8080/api/products/1
curl -X POST \
  -H 'content-type: application/json' \
  --data '{"customerEmail":"orders@example.com","items":[{"productID":1,"quantity":2},{"productID":3,"quantity":1}]}' \
  http://127.0.0.1:8080/api/orders
curl http://127.0.0.1:8080/api/orders/1001
```

## What It Demonstrates

- `AppCore` owns application construction and route declarations.
- `App` owns process startup and `--check`.
- `CommerceStore` is an `actor`, so mutable example state is concurrency-safe.
- Routes use query parameters, typed path parameters, JSON request bodies, JSON
  responses, and explicit metadata.
- Tests use `DaylilyTesting` without opening a port.

## Validate From the Repository

From the Daylily repository root:

```sh
scripts/example-smoke-test.sh --mode path
scripts/example-smoke-test.sh --mode release --version 0.1.0-alpha.1
```
