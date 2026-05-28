# Daylily Minimal App

This is the recommended minimal project shape for a small Daylily service.

```text
DaylilyMinimalApp/
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

## Why This Shape

- `AppCore` owns routes and application construction.
- `App` owns process startup.
- Tests import `AppCore` and use `DaylilyTesting` without opening a port.
- The same `makeApplication()` function powers runtime startup and tests.
- The template intentionally starts without `Dependencies`; add it only when the
  app has a shared service that benefits from app-wide wiring.

## Use It

Copy the template:

```sh
# From the Daylily repository root:
cp -R templates/minimal-app MyDaylilyApp
cd MyDaylilyApp
```

Build, test, and run checks:

```sh
swift build
swift test
swift run App --check
```

Run the server:

```sh
swift run App
```

The server listens on:

```text
http://127.0.0.1:8080
```

Try it:

```sh
curl http://127.0.0.1:8080/hello
curl http://127.0.0.1:8080/health
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/echo
```

## Adding Dependencies Later

When the app grows a real shared service, keep `makeApplication` as the single
composition point:

```swift
public struct GreetingService: Sendable {
    public let message: String

    public static let live = GreetingService(message: "Daylily minimal app ships.")

    public static func stub(_ message: String) -> GreetingService {
        GreetingService(message: message)
    }
}

public func makeApplication(greetingService: GreetingService = .live) -> Application {
    makeApplication(configureDependencies: { dependencies in
        dependencies.register(greetingService)
    })
}

public func makeApplication(
    configureDependencies: @Sendable (inout Dependencies) -> Void
) -> Application {
    Application(dependencies: configureDependencies) {
        Get("/hello") { request in
            let service = try request.dependencies.require(GreetingService.self)
            return service.message
        }
    }
}
```

Tests can then prefer the business-level override:

```swift
let client = TestClient(makeApplication(greetingService: .stub("test")))
```
