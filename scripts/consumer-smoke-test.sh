#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="path"
VERSION=""
REVISION=""
PROFILE="current"
REPO_URL="https://github.com/sinduke/Daylily.git"
PACKAGE_PATH="$REPO_ROOT"
BRANCH="main"
SMOKE_APP_PID=""
source "$SCRIPT_DIR/smoke-common.sh"
KEEP_WORKDIR="0"
WORKDIR=""

usage() {
    cat <<'USAGE'
Usage: scripts/consumer-smoke-test.sh [options]

Options:
  --mode path|release|revision|branch  Dependency source. Default: path.
  --profile current|legacy-alpha1     Capability set, independent of source. Default: current.
  --version VERSION            Required exact version for --mode release.
  --revision SHA               Required full commit SHA for --mode revision.
  --repo-url URL               Git repository URL for release/revision/branch mode.
  --package-path PATH          Local package path for --mode path.
  --branch BRANCH              Branch name for --mode branch. Default: main.
  --workdir PATH               New or empty scratch directory.
  --keep                       Keep the generated smoke package after the run.
  -h, --help                   Show this help.

Environment:
  CONSUMER_MACRO_PORT          Port for current-profile macro HTTP smoke. Default: 18080.
  SMOKE_SWIFT_VERSION          Optional exact compiler version assertion (CI uses 6.3.2).
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode|--profile|--version|--revision|--repo-url|--package-path|--branch|--workdir) smoke_require_value "$@";;
    esac
    case "$1" in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --revision)
            REVISION="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --repo-url)
            REPO_URL="$2"
            shift 2
            ;;
        --package-path)
            PACKAGE_PATH="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --workdir)
            WORKDIR="$2"
            shift 2
            ;;
        --keep)
            KEEP_WORKDIR="1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$PROFILE" in
    current|legacy-alpha1) ;;
    *) echo "Unsupported capability profile: $PROFILE" >&2; exit 2;;
esac
smoke_dependency
smoke_require_tools curl

MACRO_DEPENDENCY_SMOKE="0"
if [[ "$PROFILE" == "current" ]]; then
    MACRO_DEPENDENCY_SMOKE="1"
fi

SWIFT_LOG_SMOKE="0"
SWIFT_LOG_TEST_DEPENDENCY=""
if [[ "$PROFILE" == "current" ]]; then
    SWIFT_LOG_SMOKE="1"
    SWIFT_LOG_TEST_DEPENDENCY='                .product(name: "DaylilySwiftLog", package: "Daylily"),'
fi

SERVICE_LIFECYCLE_SMOKE="0"
SERVICE_LIFECYCLE_TEST_DEPENDENCY=""
if [[ "$PROFILE" == "current" ]]; then
    SERVICE_LIFECYCLE_SMOKE="1"
    SERVICE_LIFECYCLE_TEST_DEPENDENCY='                .product(name: "DaylilyServiceLifecycle", package: "Daylily"),'
fi

HTTP_TYPES_SMOKE="0"
HTTP_TYPES_TEST_DEPENDENCY=""
if [[ "$PROFILE" == "current" ]]; then
    HTTP_TYPES_SMOKE="1"
    HTTP_TYPES_TEST_DEPENDENCY='                .product(name: "DaylilyHTTPTypes", package: "Daylily"),'
fi

OPENAPI_TRANSPORT_SMOKE="0"
OPENAPI_TRANSPORT_TEST_DEPENDENCY=""
if [[ "$PROFILE" == "current" ]]; then
    OPENAPI_TRANSPORT_SMOKE="1"
    OPENAPI_TRANSPORT_TEST_DEPENDENCY='                .product(name: "DaylilyOpenAPITransport", package: "Daylily"),'
fi

CONSUMER_MACRO_PORT="${CONSUMER_MACRO_PORT:-18080}"

smoke_prepare_workdir
trap smoke_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p \
    "$WORKDIR/Sources/ConsumerRuntimeApp" \
    "$WORKDIR/Sources/ConsumerMacroApp" \
    "$WORKDIR/Tests/ConsumerAppTests"

cat > "$WORKDIR/Package.swift" <<SWIFT
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DaylilyConsumerSmoke",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ConsumerRuntimeApp", targets: ["ConsumerRuntimeApp"]),
        .executable(name: "ConsumerMacroApp", targets: ["ConsumerMacroApp"]),
    ],
    dependencies: [
        $DAYLILY_DEPENDENCY,
    ],
    targets: [
        .executableTarget(
            name: "ConsumerRuntimeApp",
            dependencies: [
                .product(name: "Daylily", package: "Daylily"),
            ]
        ),
        .executableTarget(
            name: "ConsumerMacroApp",
            dependencies: [
                .product(name: "Daylily", package: "Daylily"),
            ]
        ),
        .testTarget(
            name: "ConsumerAppTests",
            dependencies: [
                .product(name: "Daylily", package: "Daylily"),
                .product(name: "DaylilyTesting", package: "Daylily"),
$HTTP_TYPES_TEST_DEPENDENCY
$OPENAPI_TRANSPORT_TEST_DEPENDENCY
$SERVICE_LIFECYCLE_TEST_DEPENDENCY
$SWIFT_LOG_TEST_DEPENDENCY
            ]
        ),
    ]
)
SWIFT

cat > "$WORKDIR/Sources/ConsumerRuntimeApp/main.swift" <<'SWIFT'
import Daylily

@main
struct ConsumerRuntimeApp {
    static func main() async throws {
        if CommandLine.arguments.contains("--check") {
            try await runChecks()
            return
        }

        try await makeApplication().run()
    }

    static func makeApplication() -> Application {
        Application {
            Get("/hello") {
                "Daylily consumer runtime ships."
            }

            Post("/json/echo") { request in
                let input = try await request.json(EchoPayload.self)
                return JSON(EchoResponse(echo: input.message))
            }
        }
    }

    static func runChecks() async throws {
        let app = makeApplication()
        let response = await app.respond(to: Request(method: .get, path: "/hello"))

        guard response.status == .ok else {
            throw SmokeFailure("Expected 200 OK, got \(response.status.code)")
        }

        guard response.bodyString == "Daylily consumer runtime ships." else {
            throw SmokeFailure("Unexpected body: \(response.bodyString)")
        }

        print("Daylily consumer runtime checks passed.")
    }
}

struct EchoPayload: Codable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Sendable, Equatable {
    let echo: String
}

struct SmokeFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
SWIFT

if [[ "$MACRO_DEPENDENCY_SMOKE" == "1" ]]; then
    cat > "$WORKDIR/Sources/ConsumerMacroApp/main.swift" <<'SWIFT'
import Daylily

@main
@Use(ConsumerMiddleware.app)
@DaylilyServer
struct ConsumerMacroApp {
    func configureDependencies(_ dependencies: inout Dependencies) {
        dependencies.register(ConsumerGreetingService(prefix: "Consumer macro dependency"), for: ConsumerDependencies.greeting)
        dependencies.register("external", for: ConsumerDependencies.label)
    }

    @GET("/hello")
    func hello() -> String {
        "Daylily consumer macros ship."
    }

    @GET("/users/:id")
    func user(@Path id: Int, @Query("name") name: String) -> String {
        "User \(id): \(name)"
    }

    @GET("/dependency/:id")
    func dependency(
        @Path id: Int,
        @Dependency(ConsumerDependencies.greeting) greeting: any ConsumerGreetingServing,
        @Dependency(ConsumerDependencies.label) label: String
    ) -> String {
        "\(label):\(greeting.message(for: id))"
    }

    @GET("/optional")
    func optional(
        @Query page: Int?,
        @Query("offset") offset: Optional<Int>,
        @Header("x-label") label: String?,
        @Header("x-debug") debug: Swift.Optional<Bool>
    ) -> String {
        "\((page ?? offset).map(String.init) ?? "none"):\(label ?? debug.map(String.init) ?? "none")"
    }

    @POST("/json/echo")
    func echo(@Body input: MacroEchoPayload) -> JSON<MacroEchoResponse> {
        JSON(MacroEchoResponse(echo: input.message))
    }

    @Use(ConsumerMiddleware.named)
    @Use(ConsumerHeaderMiddleware(name: "x-consumer-route", value: "route"))
    @Security("consumerAuth")
    @GET("/middleware/route")
    func routeMiddleware() -> String {
        "route middleware"
    }

    @Use(ConsumerHeaderMiddleware(name: "x-consumer-group", value: "group"))
    @GROUP("/middleware/group")
    struct MiddlewareGroup {
        @GET("/hello")
        func hello() -> String {
            "group middleware"
        }

        @Use(ConsumerHeaderMiddleware(name: "x-consumer-route", value: "route"))
        @GET("/route")
        func route() -> String {
            "group route middleware"
        }
    }
}

struct MacroEchoPayload: Codable, Sendable {
    let message: String
}

struct MacroEchoResponse: Codable, Sendable {
    let echo: String
}

enum ConsumerDependencies {
    static let greeting = DependencyKey<any ConsumerGreetingServing>("consumer.greeting")
    static let label = DependencyKey<String>("consumer.label")
}

enum ConsumerMiddleware {
    static let app = ConsumerHeaderMiddleware(name: "x-consumer-app", value: "app")
    static let named = ConsumerHeaderMiddleware(name: "x-consumer-named", value: "named")
}

struct ConsumerHeaderMiddleware: Middleware {
    let name: String
    let value: String

    func handle(_ request: Request, next: Handler) async throws -> Response {
        var response = try await next.respond(to: request)
        response.headers[name] = value
        return response
    }
}

protocol ConsumerGreetingServing: Sendable {
    func message(for id: Int) -> String
}

struct ConsumerGreetingService: ConsumerGreetingServing {
    let prefix: String

    func message(for id: Int) -> String {
        "\(prefix) \(id)"
    }
}
SWIFT
else
    cat > "$WORKDIR/Sources/ConsumerMacroApp/main.swift" <<'SWIFT'
import Daylily

@main
@DaylilyServer
struct ConsumerMacroApp {
    @GET("/hello")
    func hello() -> String {
        "Daylily consumer macros ship."
    }

    @GET("/users/:id")
    func user(@Path id: Int, @Query("name") name: String) -> String {
        "User \(id): \(name)"
    }

    @POST("/json/echo")
    func echo(@Body input: MacroEchoPayload) -> JSON<MacroEchoResponse> {
        JSON(MacroEchoResponse(echo: input.message))
    }
}

struct MacroEchoPayload: Codable, Sendable {
    let message: String
}

struct MacroEchoResponse: Codable, Sendable {
    let echo: String
}
SWIFT
fi

cat > "$WORKDIR/Tests/ConsumerAppTests/ConsumerAppTests.swift" <<'SWIFT'
import Daylily
import DaylilyTesting
import Testing

@Test("external package consumes Daylily and DaylilyTesting")
func externalPackageConsumesDaylilyAndTesting() async throws {
    let app = Application {
        Get("/hello") {
            "Daylily consumer tests ship."
        }

        Post("/json/echo") { request in
            let input = try await request.json(EchoPayload.self)
            return JSON(EchoResponse(echo: input.message))
        }
    }

    let client = TestClient(app)
    let hello = try await client.get("/hello")
    let echo = try await client.postJSON("/json/echo", body: EchoPayload(message: "testing"))

    try hello.requireStatus(.ok)
    try hello.requireBody("Daylily consumer tests ship.")
    try echo.requireJSON(EchoResponse(echo: "testing"))
}

struct EchoPayload: Codable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Sendable, Equatable {
    let echo: String
}
SWIFT

if [[ "$SWIFT_LOG_SMOKE" == "1" ]]; then
    cat > "$WORKDIR/Tests/ConsumerAppTests/ConsumerSwiftLogTests.swift" <<'SWIFT'
import Daylily
import DaylilySwiftLog
import Testing

@Test("external package consumes DaylilySwiftLog")
func externalPackageConsumesDaylilySwiftLog() async throws {
    let app = Application {
        Get("/swift-log") {
            "swift-log"
        }
    }
    .middleware(
        RequestLoggingMiddleware(
            sink: SwiftLogRequestLogSink(label: "consumer-swift-log")
        )
    )

    let response = await app.respond(to: Request(method: .get, path: "/swift-log"))

    #expect(response.status == .ok)
    #expect(response.bodyString == "swift-log")
}
SWIFT
fi

if [[ "$HTTP_TYPES_SMOKE" == "1" ]]; then
    cat > "$WORKDIR/Tests/ConsumerAppTests/ConsumerHTTPTypesTests.swift" <<'SWIFT'
import Daylily
import DaylilyHTTPTypes
import Testing

@Test("external package consumes DaylilyHTTPTypes")
func externalPackageConsumesDaylilyHTTPTypes() throws {
    var headers = Headers()
    headers.add(name: "Set-Cookie", value: "a=1")
    headers.add(name: "Set-Cookie", value: "b=2")

    let request = Request(
        method: HTTPMethod("PROPFIND")!,
        path: "/interop?tag=tea&tag=oolong",
        headers: headers
    )

    let httpRequest = try request.httpTypesRequest()
    let roundTripped = Request(httpTypesRequest: httpRequest)

    #expect(roundTripped.method.rawValue == "PROPFIND")
    #expect(roundTripped.rawTarget == "/interop?tag=tea&tag=oolong")
    #expect(roundTripped.query.values(for: "tag") == ["tea", "oolong"])
    #expect(roundTripped.headers.values(for: "set-cookie") == ["a=1", "b=2"])
}
SWIFT
fi

if [[ "$OPENAPI_TRANSPORT_SMOKE" == "1" ]]; then
    cat > "$WORKDIR/Tests/ConsumerAppTests/ConsumerOpenAPITransportTests.swift" <<'SWIFT'
import Daylily
import DaylilyOpenAPITransport
import Testing

@Test("external package consumes DaylilyOpenAPITransport")
func externalPackageConsumesDaylilyOpenAPITransport() async throws {
    let transport = DaylilyOpenAPITransport()

    try transport.register(
        { request, _, metadata in
            #expect(request.method.rawValue == "GET")
            #expect(metadata.pathParameters["id"] == "7")
            return (.init(status: .init(code: 200)), nil)
        },
        method: .init("GET")!,
        path: "/openapi/{id}"
    )

    let response = await transport.application().respond(
        to: Request(method: .get, path: "/openapi/7")
    )

    #expect(response.status.code == 200)
}
SWIFT
fi

if [[ "$SERVICE_LIFECYCLE_SMOKE" == "1" ]]; then
    cat > "$WORKDIR/Tests/ConsumerAppTests/ConsumerServiceLifecycleTests.swift" <<'SWIFT'
import Daylily
import DaylilyServiceLifecycle
import Testing

@Test("external package consumes DaylilyServiceLifecycle")
func externalPackageConsumesDaylilyServiceLifecycle() {
    let app = Application {
        Get("/service-lifecycle") {
            "service-lifecycle"
        }
    }
    let service = app.serviceLifecycleService(configuration: .serviceLifecycleDefault)

    _ = service

    #expect(ServerConfiguration().gracefulShutdownSignals)
    #expect(ServerConfiguration.serviceLifecycleDefault.gracefulShutdownSignals == false)
}
SWIFT
fi

if [[ "$PROFILE" == "current" ]]; then
    cat > "$WORKDIR/Tests/ConsumerAppTests/ConsumerOperationTests.swift" <<'SWIFT'
import Daylily
import DaylilyServiceLifecycle
import DaylilySwiftLog
import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@Test("external package configures operation deadlines and shutdown grace")
func externalPackageConfiguresOperationDeadlines() {
    let defaults = ServerConfiguration()
    #expect(defaults.requestHeaderTimeout == .seconds(15))
    #expect(defaults.uploadIdleTimeout == .seconds(30))
    #expect(defaults.shutdownGracePeriod == .seconds(10))

    var configuration = ServerConfiguration(
        requestHeaderTimeout: .milliseconds(750),
        uploadIdleTimeout: .seconds(2),
        shutdownGracePeriod: .zero
    )
    #expect(configuration.requestHeaderTimeout == .milliseconds(750))
    #expect(configuration.uploadIdleTimeout == .seconds(2))
    #expect(configuration.shutdownGracePeriod == .zero)
    configuration.requestHeaderTimeout = nil
    configuration.uploadIdleTimeout = nil
    configuration.shutdownGracePeriod = nil
    #expect(configuration == ServerConfiguration(
        requestHeaderTimeout: nil, uploadIdleTimeout: nil, shutdownGracePeriod: nil
    ))
}

@Test("external package consumes all response transfer observer adapters")
func externalPackageConsumesResponseTransferObservers() async {
    let memory = InMemoryResponseTransferObserver()
    let observers: [any ResponseTransferObserver] = [
        memory,
        ConsoleResponseTransferObserver(),
        SwiftLogResponseTransferObserver(label: "consumer-transfer"),
    ]
    let outcomes: [ResponseTransferOutcome] = [.completed, .cancelled, .failed]
    let events = outcomes.map { outcome in
        ResponseTransferEvent(
            method: .get, path: "/transfer", status: .ok,
            requestID: "consumer-request", correlationID: "consumer-correlation",
            bytesSent: 7, durationNanoseconds: 42, outcome: outcome
        )
    }
    for event in events {
        for observer in observers { await observer.record(event) }
    }
    #expect(await memory.snapshot() == events)
    #expect(events.map(\.outcome.rawValue) == ["completed", "cancelled", "failed"])
}

@Test("external server entry points deliver actual HTTP transfer observations")
func externalServerEntryPointsDeliverTransferObservations() async throws {
    // Every supported entry point must forward its observer to the transport.
    // This intentionally uses only public products and a real HTTP connection.
    for entryPoint in ConsumerServerEntryPoint.allCases {
        let port = try consumerAvailablePort()
        let observer = InMemoryResponseTransferObserver()
        let app = Application { Get("/transfer") { "observed" } }
            .middleware(RequestIDMiddleware())
        let configuration = ServerConfiguration(
            port: port, gracefulShutdownSignals: false,
            requestHeaderTimeout: .seconds(2), uploadIdleTimeout: .seconds(2),
            shutdownGracePeriod: .milliseconds(100)
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                switch entryPoint {
                case .configuration:
                    try await app.run(configuration: configuration, responseObserver: observer)
                case .hostAndPort:
                    try await app.run(host: "127.0.0.1", port: port, responseObserver: observer)
                case .serviceHelper:
                    try await app.serviceLifecycleService(
                        configuration: configuration, responseObserver: observer
                    ).run()
                case .serviceInitializer:
                    try await DaylilyApplicationService(
                        application: app, configuration: configuration, responseObserver: observer
                    ).run()
                }
                throw ConsumerOperationFailure()
            }
            group.addTask {
                let session = URLSession(configuration: .ephemeral)
                defer { session.invalidateAndCancel() }
                var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/transfer")!)
                request.timeoutInterval = 1
                request.setValue("consumer-http", forHTTPHeaderField: "x-request-id")
                let deadline = ContinuousClock.now + .seconds(10)
                var received: (Data, URLResponse)?
                while ContinuousClock.now < deadline {
                    do {
                        received = try await session.data(for: request)
                        break
                    } catch {
                        try Task.checkCancellation()
                        try await Task.sleep(for: .milliseconds(20))
                    }
                }
                let (body, response) = try #require(received)
                #expect((response as? HTTPURLResponse)?.statusCode == 200)
                #expect(String(decoding: body, as: UTF8.self) == "observed")

                let observationDeadline = ContinuousClock.now + .seconds(5)
                while await observer.snapshot().isEmpty, ContinuousClock.now < observationDeadline {
                    try await Task.sleep(for: .milliseconds(10))
                }
                let events = await observer.snapshot()
                #expect(events.count == 1)
                let event = try #require(events.first)
                #expect(event.method == .get)
                #expect(event.path == "/transfer")
                #expect(event.status == .ok)
                #expect(event.outcome == .completed)
                #expect(event.bytesSent == 8)
                #expect(event.requestID?.hasPrefix("dl_") == true)
                #expect(event.correlationID == "consumer-http")
            }
            defer { group.cancelAll() }
            // A startup error wins immediately; otherwise the HTTP assertions
            // finish first and cancellation shuts down the server before reuse.
            _ = try await group.next()
        }
    }
}

private enum ConsumerServerEntryPoint: CaseIterable, Sendable {
    case configuration, hostAndPort, serviceHelper, serviceInitializer
}

private struct ConsumerOperationFailure: Error {}

private func consumerAvailablePort() throws -> Int {
    #if canImport(Darwin)
    let descriptor = socket(AF_INET, SOCK_STREAM, 0)
    #else
    let descriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
    #endif
    guard descriptor >= 0 else { throw ConsumerOperationFailure() }
    defer { _ = close(descriptor) }
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    let bound = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bound == 0 else { throw ConsumerOperationFailure() }
    var size = socklen_t(MemoryLayout<sockaddr_in>.size)
    let result = withUnsafeMutablePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(descriptor, $0, &size)
        }
    }
    guard result == 0 else { throw ConsumerOperationFailure() }
    return Int(UInt16(bigEndian: address.sin_port))
}
SWIFT
fi

run_macro_dependency_smoke() {
    local port="$CONSUMER_MACRO_PORT"
    local log_file="$WORKDIR/ConsumerMacroApp.log"
    local headers_file=""
    local response=""
    local started="0"
    local status="0"

    python3 - "$port" <<'PYTHON'
import socket, sys
port = int(sys.argv[1])
if not 1 <= port <= 65535:
    raise SystemExit('CONSUMER_MACRO_PORT must be between 1 and 65535')
with socket.socket() as probe:
    probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        probe.bind(('127.0.0.1', port))
    except OSError as error:
        raise SystemExit(f'Consumer smoke port {port} is unavailable: {error}')
PYTHON
    echo "Starting ConsumerMacroApp HTTP smoke on http://127.0.0.1:$port"
    # Build before the readiness timeout; slow Linux compilation is not startup failure.
    "$SMOKE_BIN_PATH/ConsumerMacroApp" --port "$port" > "$log_file" 2>&1 &
    SMOKE_APP_PID=$!
    local app_pid="$SMOKE_APP_PID"

    local deadline=$((SECONDS + 30))
    while (( SECONDS < deadline )); do
        if ! kill -0 "$app_pid" 2>/dev/null; then
            echo "ConsumerMacroApp exited before it was ready." >&2
            sed -n '1,200p' "$log_file" >&2
            wait "$app_pid" 2>/dev/null || true
            return 1
        fi

        if response="$(curl --noproxy '*' --connect-timeout 1 --max-time 5 --fail --silent --show-error "http://127.0.0.1:$port/hello" 2>/dev/null)"; then
            started="1"
            break
        fi

        sleep 0.25
    done

    if [[ "$started" != "1" ]]; then
        echo "Timed out waiting for ConsumerMacroApp to start." >&2
        sed -n '1,200p' "$log_file" >&2
        status="1"
    elif [[ "$response" != "Daylily consumer macros ship." ]]; then
        echo "Unexpected ConsumerMacroApp /hello response: $response" >&2
        status="1"
    elif [[ "$PROFILE" == "current" ]]; then
        response="$(curl --noproxy '*' --connect-timeout 1 --max-time 5 --fail --silent --show-error "http://127.0.0.1:$port/dependency/42" 2>/dev/null || true)"
        if [[ "$response" != "external:Consumer macro dependency 42" ]]; then
            echo "Unexpected ConsumerMacroApp dependency response: $response" >&2
            sed -n '1,200p' "$log_file" >&2
            status="1"
        fi

        response="$(curl --noproxy '*' --connect-timeout 1 --max-time 5 --fail --silent --show-error "http://127.0.0.1:$port/optional" || true)"
        if [[ "$response" != "none:none" ]]; then
            echo "Optional macro inputs did not preserve missing values: $response" >&2
            status="1"
        fi
        response="$(curl --noproxy '*' --connect-timeout 1 --max-time 5 --fail --silent --show-error -H 'x-label: external' "http://127.0.0.1:$port/optional?page=7" || true)"
        if [[ "$response" != "7:external" ]]; then
            echo "Optional macro inputs did not decode present values: $response" >&2
            status="1"
        fi
        response="$(curl --noproxy '*' --connect-timeout 1 --max-time 5 --silent --show-error --output /dev/null --write-out '%{http_code}' "http://127.0.0.1:$port/optional?page=invalid" || true)"
        if [[ "$response" != "400" ]]; then
            echo "Invalid optional query should return 400, got: $response" >&2
            status="1"
        fi

        headers_file="$WORKDIR/ConsumerMacroApp-route.headers"
        response="$(curl --noproxy '*' --connect-timeout 1 --max-time 5 --fail --silent --show-error --dump-header "$headers_file" "http://127.0.0.1:$port/middleware/route" 2>/dev/null || true)"
        if [[ "$response" != "route middleware" ]]; then
            echo "Unexpected ConsumerMacroApp route middleware response: $response" >&2
            sed -n '1,200p' "$log_file" >&2
            status="1"
        elif ! grep -qi '^x-consumer-app: app' "$headers_file"; then
            echo "Missing app middleware header on route middleware response." >&2
            sed -n '1,120p' "$headers_file" >&2
            status="1"
        elif ! grep -qi '^x-consumer-named: named' "$headers_file"; then
            echo "Missing named middleware header on route middleware response." >&2
            sed -n '1,120p' "$headers_file" >&2
            status="1"
        elif ! grep -qi '^x-consumer-route: route' "$headers_file"; then
            echo "Missing route middleware header on route middleware response." >&2
            sed -n '1,120p' "$headers_file" >&2
            status="1"
        fi

        headers_file="$WORKDIR/ConsumerMacroApp-group-route.headers"
        response="$(curl --noproxy '*' --connect-timeout 1 --max-time 5 --fail --silent --show-error --dump-header "$headers_file" "http://127.0.0.1:$port/middleware/group/route" 2>/dev/null || true)"
        if [[ "$response" != "group route middleware" ]]; then
            echo "Unexpected ConsumerMacroApp group route middleware response: $response" >&2
            sed -n '1,200p' "$log_file" >&2
            status="1"
        elif ! grep -qi '^x-consumer-app: app' "$headers_file"; then
            echo "Missing app middleware header on group route middleware response." >&2
            sed -n '1,120p' "$headers_file" >&2
            status="1"
        elif ! grep -qi '^x-consumer-group: group' "$headers_file"; then
            echo "Missing group middleware header on group route middleware response." >&2
            sed -n '1,120p' "$headers_file" >&2
            status="1"
        elif ! grep -qi '^x-consumer-route: route' "$headers_file"; then
            echo "Missing route middleware header on group route middleware response." >&2
            sed -n '1,120p' "$headers_file" >&2
            status="1"
        fi
    fi

    smoke_stop_app

    if [[ "$status" == "0" ]]; then
        echo "ConsumerMacroApp dependency checks passed."
    fi

    return "$status"
}

run_macro_diagnostics_smoke() {
    mkdir -p "$WORKDIR/Fixtures/InvalidPathFixture"
    cat > "$WORKDIR/Fixtures/InvalidPathFixture/main.swift" <<'SWIFT'
import Daylily

@main
@DaylilyServer
struct InvalidPathFixture {
    @GET("/users/:id")
    func user(@Path id: Int?) -> String {
        "invalid"
    }
}
SWIFT
    # Add the intentionally invalid target only after normal builds and tests.
    cp "$WORKDIR/Package.swift" "$WORKDIR/Package.swift.valid"
    python3 - "$WORKDIR/Package.swift" <<'PYTHON'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
fixture = '.executableTarget(name: "InvalidPathFixture", dependencies: [.product(name: "Daylily", package: "Daylily")], path: "Fixtures/InvalidPathFixture"),'
path.write_text(text.replace('    targets: [', '    targets: [\n        ' + fixture, 1))
PYTHON
    local compiled=0
    if swift build --target InvalidPathFixture > "$WORKDIR/macro-diagnostics.log" 2>&1; then
        compiled=1
    fi
    mv "$WORKDIR/Package.swift.valid" "$WORKDIR/Package.swift"
    if [[ "$compiled" == 1 ]]; then
        echo 'Optional @Path unexpectedly compiled.' >&2
        return 1
    fi
    python3 - "$WORKDIR/macro-diagnostics.log" <<'PYTHON'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
if '@Path parameters cannot be optional' not in text:
    print(text, file=sys.stderr)
    raise SystemExit('Compilation failed without the expected optional @Path diagnostic')
print('Optional @Path compile diagnostic passed.')
PYTHON
}

echo "Consumer smoke package: $WORKDIR"
echo "Dependency mode: $MODE"
echo "Capability profile: $PROFILE"
echo "Macro dependency runtime smoke: $MACRO_DEPENDENCY_SMOKE"
echo "SwiftLog adapter smoke: $SWIFT_LOG_SMOKE"
echo "ServiceLifecycle adapter smoke: $SERVICE_LIFECYCLE_SMOKE"
echo "Swift HTTP Types adapter smoke: $HTTP_TYPES_SMOKE"
echo "Swift OpenAPI Generator transport smoke: $OPENAPI_TRANSPORT_SMOKE"

cd "$WORKDIR"
swift package resolve
smoke_record_dependency
swift build --product ConsumerRuntimeApp
swift build --product ConsumerMacroApp
swift test
SMOKE_BIN_PATH="$(swift build --show-bin-path)"
"$SMOKE_BIN_PATH/ConsumerRuntimeApp" --check
if [[ "$PROFILE" == "current" ]]; then
    run_macro_dependency_smoke
    run_macro_diagnostics_smoke
fi

echo "Daylily external consumer smoke passed ($MODE, $PROFILE)."
