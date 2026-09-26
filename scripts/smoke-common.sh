#!/usr/bin/env bash

# Shared by external package smoke scripts. This file is sourced, not executed.
smoke_require_tools() {
    local tool
    for tool in swift git python3 "$@"; do
        command -v "$tool" >/dev/null 2>&1 || {
            echo "Required smoke dependency is missing: $tool" >&2
            return 1
        }
    done
    swift --version
    if [[ -n "${SMOKE_SWIFT_VERSION:-}" ]]; then
        swift --version | python3 -c 'import re, sys; expected = sys.argv[1]; actual = re.search(r"Swift version ([0-9.]+)", sys.stdin.read()); sys.exit(0 if actual and actual.group(1) == expected else "Expected Swift " + expected)' "$SMOKE_SWIFT_VERSION"
    fi
}

smoke_require_value() {
    [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || {
        echo "Missing value for $1" >&2
        exit 2
    }
}

swift_string_literal() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '"%s"' "$value"
}

smoke_dependency() {
    case "$MODE" in
        path)
            [[ -f "$PACKAGE_PATH/Package.swift" ]] || { echo "Missing Package.swift: $PACKAGE_PATH" >&2; exit 2; }
            PACKAGE_PATH="$(cd "$PACKAGE_PATH" && pwd)"
            DAYLILY_DEPENDENCY=".package(name: \"Daylily\", path: $(swift_string_literal "$PACKAGE_PATH"))"
            ;;
        release)
            [[ -n "$VERSION" ]] || { echo '--version is required for release mode' >&2; exit 2; }
            DAYLILY_DEPENDENCY=".package(name: \"Daylily\", url: $(swift_string_literal "$REPO_URL"), .exact($(swift_string_literal "${VERSION#v}")))"
            ;;
        revision)
            [[ "$REVISION" =~ ^[0-9a-fA-F]{40}$ ]] || { echo '--revision requires a full 40-character commit SHA' >&2; exit 2; }
            DAYLILY_DEPENDENCY=".package(name: \"Daylily\", url: $(swift_string_literal "$REPO_URL"), revision: $(swift_string_literal "$REVISION"))"
            ;;
        branch)
            DAYLILY_DEPENDENCY=".package(name: \"Daylily\", url: $(swift_string_literal "$REPO_URL"), branch: $(swift_string_literal "$BRANCH"))"
            ;;
        *) echo "Unsupported mode: $MODE" >&2; exit 2;;
    esac
}

smoke_prepare_workdir() {
    if [[ -z "$WORKDIR" ]]; then
        WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/daylily-smoke.XXXXXX")"
    else
        mkdir -p "$WORKDIR"
        [[ -z "$(ls -A "$WORKDIR")" ]] || { echo '--workdir must be new or empty' >&2; exit 2; }
        WORKDIR="$(cd "$WORKDIR" && pwd)"
    fi
}

smoke_stop_app() {
    if [[ -n "${SMOKE_APP_PID:-}" ]]; then
        kill "$SMOKE_APP_PID" 2>/dev/null || true
        for _ in {1..40}; do
            kill -0 "$SMOKE_APP_PID" 2>/dev/null || break
            sleep 0.25
        done
        kill -KILL "$SMOKE_APP_PID" 2>/dev/null || true
        wait "$SMOKE_APP_PID" 2>/dev/null || true
        SMOKE_APP_PID=""
    fi
}

smoke_cleanup() {
    smoke_stop_app
    if [[ "$KEEP_WORKDIR" == 1 ]]; then
        echo "Kept smoke package at $WORKDIR"
    else
        rm -rf "$WORKDIR"
    fi
}

# Save the actual resolver outcome alongside Package.resolved for CI artifacts.
smoke_record_dependency() {
    python3 - "$MODE" "$PACKAGE_PATH" "$REPO_URL" "$VERSION" "$REVISION" "$PROFILE" <<'PY'
import json, pathlib, subprocess, sys, urllib.parse
mode, local_path, repo, version, revision, profile = sys.argv[1:]
record = {"mode": mode, "profile": profile}
if mode == "path":
    def git(*args):
        return subprocess.run(["git", "-C", local_path, *args], capture_output=True, text=True)
    head = git("rev-parse", "HEAD")
    status = git("status", "--porcelain")
    record.update(path=local_path, baseRevision=head.stdout.strip() if head.returncode == 0 else None,
                  workingTreeChanges=bool(status.stdout) if status.returncode == 0 else None)
else:
    pins = json.loads(pathlib.Path("Package.resolved").read_text())["pins"]
    def normalized_location(value):
        if value.startswith("file://"):
            return str(pathlib.Path(urllib.parse.unquote(urllib.parse.urlparse(value).path)).resolve())
        if value.startswith(("/", "./", "../")):
            return str(pathlib.Path(value).resolve())
        return value.rstrip("/").removesuffix(".git")
    pin = next((p for p in pins if normalized_location(p.get("location", "")) == normalized_location(repo)), None)
    if pin is None:
        pin = next((p for p in pins if p["identity"].lower() == "daylily"), None)
    if pin is None:
        raise SystemExit("Daylily pin is missing from Package.resolved")
    state = pin["state"]
    if mode == "revision" and state["revision"].lower() != revision.lower():
        raise SystemExit("Resolved Daylily revision does not match requested SHA")
    if mode == "release" and state.get("version") != version.removeprefix("v"):
        raise SystemExit("Resolved Daylily version does not match requested exact version")
    record.update(repository=repo, identity=pin["identity"], resolved=state)
pathlib.Path("dependency-record.json").write_text(json.dumps(record, indent=2) + "\n")
print("Resolved Daylily: " + json.dumps(record, sort_keys=True))
PY
}
