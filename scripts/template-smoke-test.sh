#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="path"
VERSION="0.1.0-alpha.1"
REPO_URL="https://github.com/sinduke/Daylily.git"
PACKAGE_PATH="$REPO_ROOT"
TEMPLATE_DIR="$REPO_ROOT/templates/minimal-app"
SMOKE_NAME="minimal app template"
BRANCH="main"
KEEP_WORKDIR="0"
WORKDIR=""

usage() {
    cat <<'USAGE'
Usage: scripts/template-smoke-test.sh [options]

Options:
  --mode path|release|branch   Dependency mode. Default: path.
  --version VERSION            Release version for --mode release. Default: 0.1.0-alpha.1.
  --repo-url URL               Git repository URL for release/branch mode.
  --package-path PATH          Local package path for --mode path.
  --template-dir PATH          Template directory to copy.
  --name NAME                  Human-readable smoke name. Default: minimal app template.
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
        --template-dir)
            TEMPLATE_DIR="$2"
            shift 2
            ;;
        --name)
            SMOKE_NAME="$2"
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

replace_dependency() {
    local package_file="$1"
    local dependency="$2"
    local tmp_file="$package_file.tmp"

    awk -v dependency="$dependency" '
        /\/\/ DAYLILY_DEPENDENCY_START/ {
            print
            print "        " dependency
            skip = 1
            next
        }
        /\/\/ DAYLILY_DEPENDENCY_END/ {
            skip = 0
            print
            next
        }
        !skip {
            print
        }
    ' "$package_file" > "$tmp_file"

    mv "$tmp_file" "$package_file"
}

case "$MODE" in
    path)
        PACKAGE_PATH="$(absolute_path "$PACKAGE_PATH")"
        DAYLILY_DEPENDENCY=".package(name: \"Daylily\", path: $(swift_string_literal "$PACKAGE_PATH")),"
        ;;
    release)
        DAYLILY_DEPENDENCY=".package(url: $(swift_string_literal "$REPO_URL"), from: $(swift_string_literal "$VERSION")),"
        ;;
    branch)
        DAYLILY_DEPENDENCY=".package(url: $(swift_string_literal "$REPO_URL"), branch: $(swift_string_literal "$BRANCH")),"
        ;;
    *)
        echo "Unsupported mode: $MODE" >&2
        usage >&2
        exit 2
        ;;
esac

TEMPLATE_DIR="$(absolute_path "$TEMPLATE_DIR")"
if [[ ! -f "$TEMPLATE_DIR/Package.swift" ]]; then
    echo "Template directory is missing Package.swift: $TEMPLATE_DIR" >&2
    exit 1
fi

if [[ -z "$WORKDIR" ]]; then
    WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/daylily-template-smoke.XXXXXX")"
else
    mkdir -p "$WORKDIR"
    WORKDIR="$(absolute_path "$WORKDIR")"
fi

cleanup() {
    if [[ "$KEEP_WORKDIR" != "1" ]]; then
        rm -rf "$WORKDIR"
    else
        echo "Kept template smoke package at $WORKDIR"
    fi
}
trap cleanup EXIT

cp -R "$TEMPLATE_DIR/." "$WORKDIR/"
replace_dependency "$WORKDIR/Package.swift" "$DAYLILY_DEPENDENCY"

echo "Smoke package: $WORKDIR"
echo "Smoke target: $SMOKE_NAME"
echo "Dependency mode: $MODE"

(
    cd "$WORKDIR"
    swift package resolve
    swift build
    swift test
    swift run App --check
)

echo "Daylily $SMOKE_NAME smoke passed ($MODE)."
