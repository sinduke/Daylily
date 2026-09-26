# 02 Replace a dependency implementation

Starting point: the greeting handler constructs `CasualGreeting()` directly and
returns `Hi, <name>!`. Its `GreetingProvider: Sendable` protocol defines
`func greet(_ name: String) -> String`; the route metadata is already correct.

Request: make the default implementation `FormalGreeting`, returning
`Welcome, <name>.`. Register the selected `any GreetingProvider` under a typed
`DependencyKey` in the application's composition root. Resolve that key in the
handler. `ReplaceDependency.application(provider:)` must allow an application or
test to replace the implementation without editing route code.

Acceptance:

- Default composition returns `Welcome, Ada.`.
- Injecting `CasualGreeting()` returns `Hi, Ada!` on the same path.
- An independently defined test provider receives the actual requested name.
- Swapping implementations leaves `Application.describeRoutes()` identical.

Completed reference: `Sources/ApplicationExercises/ReplaceDependency.swift`.
Executable checks: `ReplaceDependencyAcceptance` (2 tests).
