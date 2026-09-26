#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/smoke-common.sh"
MODE=path
PACKAGE_PATH="$REPO_ROOT"
REPO_URL=https://github.com/sinduke/Daylily.git
VERSION=""
REVISION=""
BRANCH=main
PROFILE=contract-regression
WORKDIR=""
KEEP_WORKDIR=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode|--package-path|--repo-url|--version|--revision|--workdir)
            smoke_require_value "$@"
            case "$1" in
                --mode) MODE="$2";; --package-path) PACKAGE_PATH="$2";; --repo-url) REPO_URL="$2";;
                --version) VERSION="$2";; --revision) REVISION="$2";; --workdir) WORKDIR="$2";;
            esac
            shift 2;;
        --keep) KEEP_WORKDIR=1; shift;;
        --help|-h)
            echo 'Usage: scripts/contract-regression-test.sh [--mode path|revision|release] [--package-path PATH] [--repo-url URL] [--revision SHA] [--version VERSION] [--workdir EMPTY] [--keep]'
            echo 'Environment: CONTRACT_PORT (default 18085), SMOKE_SWIFT_VERSION, DEVELOPER_DIR.'
            exit 0;;
        *) echo "Unknown option: $1" >&2; exit 2;;
    esac
done
smoke_dependency
smoke_require_tools
smoke_prepare_workdir
trap smoke_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
FIXTURES="$REPO_ROOT/ai/evals/contracts"
python3 "$FIXTURES/test_compatibility.py"
python3 "$SCRIPT_DIR/openapi-compatibility-check.py" "$FIXTURES/old.json" "$FIXTURES/compatible.json" --output "$WORKDIR/compatible-diff.json"
set +e
python3 "$SCRIPT_DIR/openapi-compatibility-check.py" "$FIXTURES/old.json" "$FIXTURES/breaking-required.json" --output "$WORKDIR/breaking-diff.json"
compatibility_status=$?
set -e
[[ "$compatibility_status" == 1 ]] || { echo 'Required request addition was not rejected as a supported breaking change' >&2; exit 1; }
cat > "$WORKDIR/Package.swift" <<SWIFT
// swift-tools-version: 6.3
import PackageDescription
let package = Package(name: "DaylilyContractRegression", platforms: [.macOS(.v14)], dependencies: [
    $DAYLILY_DEPENDENCY,
    .package(url: "https://github.com/apple/swift-openapi-generator.git", exact: "1.13.1"),
    .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.0"),
    .package(url: "https://github.com/apple/swift-openapi-urlsession.git", exact: "1.3.1"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.13.0"),
    .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.11.0"),
], targets: [
    .target(name: "OldAPI", dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")], plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]),
    .target(name: "NewAPI", dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")], plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]),
    .target(name: "BreakingAPI", dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")], plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]),
    .executableTarget(name: "ContractRegression", dependencies: ["OldAPI", "NewAPI", "BreakingAPI",
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "DaylilyCore", package: "Daylily"),
        .product(name: "DaylilyOpenAPITransport", package: "Daylily"),
        .product(name: "DaylilyServiceLifecycle", package: "Daylily"),
        .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
    ]),
])
SWIFT
for target in OldAPI NewAPI BreakingAPI; do
    mkdir -p "$WORKDIR/Sources/$target"
    printf '// Generated contracts are built by the Swift OpenAPI Generator plugin.\n' > "$WORKDIR/Sources/$target/Marker.swift"
    printf 'generate:\n  - types\n  - client\n  - server\naccessModifier: public\n' > "$WORKDIR/Sources/$target/openapi-generator-config.yaml"
done
cp "$FIXTURES/old.json" "$WORKDIR/Sources/OldAPI/openapi.json"
cp "$FIXTURES/compatible.json" "$WORKDIR/Sources/NewAPI/openapi.json"
cp "$FIXTURES/breaking-required.json" "$WORKDIR/Sources/BreakingAPI/openapi.json"
mkdir -p "$WORKDIR/Sources/ContractRegression"
cp "$FIXTURES/HTTPRegression.swift" "$WORKDIR/Sources/ContractRegression/ContractRegression.swift"
cd "$WORKDIR"
swift package resolve
smoke_record_dependency
swift build --product ContractRegression
bin_path="$(swift build --show-bin-path)"
python3 - "$bin_path/ContractRegression" <<'PY'
import os, socket, subprocess, sys
port = int(os.environ.get('CONTRACT_PORT', '18085'))
if not 1 <= port <= 65535: raise SystemExit('Invalid CONTRACT_PORT')
with socket.socket() as probe:
    probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    probe.bind(('127.0.0.1', port))
subprocess.run([sys.argv[1]], check=True, timeout=90)
PY
