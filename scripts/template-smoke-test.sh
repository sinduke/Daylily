#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="path"
VERSION=""
REVISION=""
PROFILE="template"
REPO_URL="https://github.com/sinduke/Daylily.git"
PACKAGE_PATH="$REPO_ROOT"
TEMPLATE_DIR="$REPO_ROOT/templates/minimal-app"
SMOKE_NAME="minimal app template"
BRANCH="main"
KEEP_WORKDIR="0"
WORKDIR=""
source "$SCRIPT_DIR/smoke-common.sh"

usage() {
    cat <<'USAGE'
Usage: scripts/template-smoke-test.sh [options]

Options:
  --mode path|release|revision|branch  Dependency source. Default: path.
  --version VERSION            Required exact release version.
  --revision SHA               Required full commit SHA for revision mode.
  --repo-url URL               Git repository URL for release/revision/branch mode.
  --package-path PATH          Local package path for --mode path.
  --template-dir PATH          Template directory to copy.
  --name NAME                  Human-readable smoke name. Default: minimal app template.
  --branch BRANCH              Branch name for --mode branch. Default: main.
  --workdir PATH               New or empty scratch directory.
  --keep                       Keep the generated smoke package after the run.
  -h, --help                   Show this help.
Environment: SMOKE_SWIFT_VERSION optionally asserts the exact compiler version.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode|--version|--revision|--repo-url|--package-path|--template-dir|--name|--branch|--workdir) smoke_require_value "$@";;
    esac
    case "$1" in
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

PROFILE="$SMOKE_NAME"
smoke_dependency
smoke_require_tools

TEMPLATE_DIR="$(cd "$TEMPLATE_DIR" && pwd)"
if [[ ! -f "$TEMPLATE_DIR/Package.swift" ]]; then
    echo "Template directory is missing Package.swift: $TEMPLATE_DIR" >&2
    exit 1
fi

smoke_prepare_workdir
trap smoke_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Copy project inputs only; never copy a potentially huge local build/cache tree.
cp "$TEMPLATE_DIR/Package.swift" "$WORKDIR/Package.swift"
cp -R "$TEMPLATE_DIR/Sources" "$WORKDIR/Sources"
if [[ -d "$TEMPLATE_DIR/Tests" ]]; then
    cp -R "$TEMPLATE_DIR/Tests" "$WORKDIR/Tests"
fi
python3 - "$WORKDIR/Package.swift" "$DAYLILY_DEPENDENCY" <<'PYTHON'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
start = text.index("        // DAYLILY_DEPENDENCY_START")
end = text.index("        // DAYLILY_DEPENDENCY_END", start)
path.write_text(text[:start] + "        // DAYLILY_DEPENDENCY_START\n        " + sys.argv[2] + ",\n" + text[end:])
PYTHON

echo "Smoke package: $WORKDIR"
echo "Smoke target: $SMOKE_NAME"
echo "Dependency mode: $MODE"

(
    cd "$WORKDIR"
    swift package resolve
    smoke_record_dependency
    swift build
    swift test
    SMOKE_BIN_PATH="$(swift build --show-bin-path)"
    "$SMOKE_BIN_PATH/App" --check
)

echo "Daylily $SMOKE_NAME smoke passed ($MODE)."
