# Quick Start

This guide uses the Daylily repository checkout directly. Package installation docs will come after release hygiene and tagging work.

## Requirements

- Swift 6 toolchain.
- macOS 14+ for the current package declaration.
- Xcode toolchain for Swift Testing if Command Line Tools cannot find the `Testing` module.

## Clone and Build

```sh
git clone https://github.com/sinduke/Daylily.git
cd Daylily
swift build
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

Daylily's intended user-facing shape is macro-driven:

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

Macros lower into the runtime route system. The runtime remains the source of truth.

## Minimal Runtime Shape

The runtime DSL is available directly:

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

## Next Steps

- Read the [JSON API example](examples/json-api.md).
- Read the [middleware example](examples/middleware.md).
- Read the [testing example](examples/testing.md).
- Check the [capability matrix](capability-matrix.md).
