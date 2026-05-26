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
