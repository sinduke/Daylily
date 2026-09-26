#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/smoke-common.sh"
MODE=path
PACKAGE_PATH="$REPO_ROOT"
WORKDIR=""
KEEP_WORKDIR=0
REPO_URL=""
VERSION=""
REVISION=""
PROFILE=application-exercises

usage() {
    cat <<'USAGE'
Usage: scripts/ai-exercises-smoke-test.sh [options]
  --mode path             Only local checkout mode is supported.
  --package-path PATH     Daylily checkout (default: this repository).
  --workdir PATH          New or empty external package directory.
  --keep                  Preserve the scratch package and resolver record.
  -h, --help              Show help.
Environment: DEVELOPER_DIR (optional Xcode selection), SMOKE_SWIFT_VERSION (optional exact toolchain).
Runs three concrete application-change exercises; this is not a general AI benchmark.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode|--package-path|--workdir)
            smoke_require_value "$@"
            case "$1" in
                --mode) MODE="$2";;
                --package-path) PACKAGE_PATH="$2";;
                --workdir) WORKDIR="$2";;
            esac
            shift 2;;
        --keep) KEEP_WORKDIR=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
    esac
done
[[ "$MODE" == path ]] || { echo 'Application exercises support --mode path only' >&2; exit 2; }
smoke_require_tools
smoke_dependency
smoke_prepare_workdir
trap smoke_cleanup EXIT

FIXTURE="$REPO_ROOT/ai/evals/application-changes"
cp "$FIXTURE/Package.swift" "$WORKDIR/Package.swift"
cp -R "$FIXTURE/Sources" "$FIXTURE/Tests" "$WORKDIR/"
python3 - "$WORKDIR/Package.swift" "$DAYLILY_DEPENDENCY" <<'PY'
from pathlib import Path
import sys
manifest = Path(sys.argv[1])
source = manifest.read_text()
original = '.package(name: "Daylily", path: "../../..")'
if source.count(original) != 1:
    raise SystemExit('Unexpected exercise manifest dependency marker')
manifest.write_text(source.replace(original, sys.argv[2]))
PY

echo "Application exercise package: $WORKDIR"
cd "$WORKDIR"
swift package resolve
smoke_record_dependency
swift test
echo 'Three concrete application changes passed six acceptance tests: endpoint, typed dependency replacement, DTO/schema evolution.'
