#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="path"
VERSION="0.1.0-alpha.1"
REPO_URL="https://github.com/sinduke/Daylily.git"
PACKAGE_PATH="$REPO_ROOT"
BRANCH="main"
KEEP_WORKDIR="0"
WORKDIR=""

usage() {
    cat <<'USAGE'
Usage: scripts/consumer-smoke-test.sh [options]

Options:
  --mode path|release|branch   Dependency mode. Default: path.
  --version VERSION            Release version for --mode release. Default: 0.1.0-alpha.1.
  --repo-url URL               Git repository URL for release/branch mode.
  --package-path PATH          Local package path for --mode path.
  --branch BRANCH              Branch name for --mode branch. Default: main.
  --workdir PATH               Reuse or create the smoke package in PATH.
  --keep                       Keep the generated smoke package after the run.
  -h, --help                   Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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

swift_string_literal() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    printf '"%s"' "$value"
}

absolute_path() {
    local path="$1"
    if [[ "$path" = /* ]]; then
        printf '%s\n' "$path"
    else
        printf '%s\n' "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi
}

case "$MODE" in
    path)
        PACKAGE_PATH="$(absolute_path "$PACKAGE_PATH")"
        DAYLILY_DEPENDENCY=".package(path: $(swift_string_literal "$PACKAGE_PATH"))"
        ;;
    release)
        DAYLILY_DEPENDENCY=".package(url: $(swift_string_literal "$REPO_URL"), from: $(swift_string_literal "$VERSION"))"
        ;;
    branch)
        DAYLILY_DEPENDENCY=".package(url: $(swift_string_literal "$REPO_URL"), branch: $(swift_string_literal "$BRANCH"))"
        ;;
    *)
        echo "Unsupported mode: $MODE" >&2
        usage >&2
        exit 2
        ;;
esac

if [[ -z "$WORKDIR" ]]; then
    WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/daylily-consumer-smoke.XXXXXX")"
else
    mkdir -p "$WORKDIR"
    WORKDIR="$(absolute_path "$WORKDIR")"
fi

cleanup() {
    if [[ "$KEEP_WORKDIR" != "1" ]]; then
        rm -rf "$WORKDIR"
    else
        echo "Kept consumer smoke package at $WORKDIR"
    fi
}
trap cleanup EXIT

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

echo "Consumer smoke package: $WORKDIR"
echo "Dependency mode: $MODE"

(
    cd "$WORKDIR"
    swift package resolve
    swift build --product ConsumerRuntimeApp
    swift build --product ConsumerMacroApp
    swift test
    swift run ConsumerRuntimeApp --check
)

echo "Daylily external consumer smoke passed ($MODE)."
