# Quick Start

This guide covers both SwiftPM package usage and running the Daylily repository checkout directly.

## Requirements

- Swift 6 toolchain.
- macOS 14+ for local package development today.
- Linux is validated in GitHub Actions with the official Swift Docker image.
- Xcode toolchain for Swift Testing if Command Line Tools cannot find the `Testing` module.

## Install with SwiftPM

Add Daylily as a package dependency:

```swift
.package(url: "https://github.com/sinduke/Daylily.git", from: "0.1.0-alpha.1")
```

Documentation on `main` may describe APIs newer than the latest tag. The `Dependencies` registry is available from the source checkout and will be included in a future pre-release tag.

Add the product to your target:

```swift
.product(name: "Daylily", package: "Daylily")
```

Daylily validates this external package path with a generated consumer smoke package:

```sh
scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1
```

## Clone and Build

For local framework development or examples, use the repository checkout:

```sh
git clone https://github.com/sinduke/Daylily.git
cd Daylily
swift build
```

To validate a local checkout as an external package dependency:

```sh
scripts/consumer-smoke-test.sh --mode path
```

## Start from the Minimal Template

Copy the recommended external app shape:

```sh
cp -R templates/minimal-app MyDaylilyApp
cd MyDaylilyApp
```

Build, test, and run the template smoke check:

```sh
swift build
swift test
swift run App --check
```

Daylily validates the template in both local path and released package modes:

```sh
scripts/template-smoke-test.sh --mode path
scripts/template-smoke-test.sh --mode release --version 0.1.0-alpha.1
```

## Run the Commerce API Example

The first real API example lives in `examples/commerce-api`. It demonstrates a
small product and order service with state, JSON DTOs, typed path/query inputs,
route metadata, the `Dependencies` registry, and transport-free tests.

Validate it from the repository root:

```sh
scripts/example-smoke-test.sh --mode path
```

Or run it directly:

```sh
cd examples/commerce-api
swift build
swift test
swift run App --check
swift run App
```

## Run Checks

Daylily keeps a shared behavior check suite that is used by both the example executable and formal tests:

```sh
swift run HelloDaylily --check
```

Run tests:

```sh
swift test
```

If `swift test` reports `no such module 'Testing'` while `xcode-select -p` points at Command Line Tools, run it with the installed Xcode developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test
```

## Run the Example Server

```sh
swift run
```

The example server listens on:

```text
http://127.0.0.1:8080
```

Try a few routes:

```sh
curl http://127.0.0.1:8080/hello
curl http://127.0.0.1:8080/users/42
curl 'http://127.0.0.1:8080/search?term=daylily&page=1'
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/json/echo
```

Stop the server with `Ctrl-C`.

## Minimal Macro App Shape

Daylily offers a macro-driven default shape:

```swift
import Daylily

@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }
}
```

Macros lower into the runtime route system. The runtime remains the source of truth, and the macro shape is optional.

## Minimal Runtime Shape

The runtime DSL is available directly and remains a first-class application shape:

```swift
import Daylily

@main
struct App {
    static func main() async throws {
        let app = Application {
            Get("/hello") {
                "Daylily ships."
            }
        }

        try await app.run()
    }
}
```

## Default Path, Not Mandatory Path

Daylily's built-in APIs are recommended defaults, not architectural monopolies. A real app can keep its own composition root and services:

```swift
let services = MyServices()

let app = Application {
    Get("/products") { _ in
        try await services.products.list()
    }
}
```

The `Dependencies` registry provides a Daylily-owned default channel for common cases:

```swift
let app = Application(dependencies: { dependencies in
    dependencies.register(ProductService())
}) {
    Get("/products") { request in
        let service = try request.dependencies.require(ProductService.self)
        return JSON(try await service.list())
    }
}
```

It is not required for applications that already have their own factories, service containers, or module wiring.

## Next Steps

- Read the [JSON API example](examples/json-api.md).
- Read the [Dependencies usage guide](examples/dependencies.md).
- Read the [commerce API example](examples/commerce-api.md).
- Read the [middleware example](examples/middleware.md).
- Read the [testing example](examples/testing.md).
- Check the [capability matrix](capability-matrix.md).
- Check [release readiness](release-readiness.md).
