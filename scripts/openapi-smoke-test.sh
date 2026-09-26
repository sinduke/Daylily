#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE=path
PACKAGE_PATH="$REPO_ROOT"
REPO_URL="https://github.com/sinduke/Daylily.git"
VERSION=""
REVISION=""
WORKDIR=""
KEEP=0

usage() {
    cat <<'USAGE'
Usage: scripts/openapi-smoke-test.sh [options]
  --mode path|revision|release  Dependency source; all modes run the same checks.
  --package-path PATH          Daylily checkout for path mode.
  --repo-url URL               Repository for revision/release mode.
  --revision SHA               Required exact commit for revision mode.
  --version VERSION            Required exact version for release mode.
  --workdir PATH               New or empty scratch directory.
  --keep                       Preserve scratch package and generated code.
  -h, --help                   Show help.
Environment: OPENAPI_PORT (default 18083), DEVELOPER_DIR (optional Xcode override).
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode|--package-path|--repo-url|--revision|--version|--workdir)
            [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
            case "$1" in
                --mode) MODE="$2";;
                --package-path) PACKAGE_PATH="$2";;
                --repo-url) REPO_URL="$2";;
                --revision) REVISION="$2";;
                --version) VERSION="$2";;
                --workdir) WORKDIR="$2";;
            esac
            shift 2;;
        --keep) KEEP=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
    esac
done

case "$MODE" in
    path) PACKAGE_PATH="$(cd "$PACKAGE_PATH" && pwd)";;
    revision) [[ "$REVISION" =~ ^[0-9a-fA-F]{40}$ ]] || { echo '--revision requires a full 40-character commit SHA' >&2; exit 2; };;
    release) [[ -n "$VERSION" ]] || { echo '--version is required' >&2; exit 2; };;
    *) echo "Unsupported mode: $MODE" >&2; exit 2;;
esac

if [[ -z "$WORKDIR" ]]; then
    WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/daylily-openapi-smoke.XXXXXX")"
else
    mkdir -p "$WORKDIR"
    [[ -z "$(ls -A "$WORKDIR")" ]] || { echo '--workdir must be empty' >&2; exit 2; }
    WORKDIR="$(cd "$WORKDIR" && pwd)"
fi
cleanup() {
    if [[ "$KEEP" == 1 ]]; then
        echo "Kept OpenAPI smoke package: $WORKDIR"
    else
        rm -rf "$WORKDIR"
    fi
}
trap cleanup EXIT

# Copy source files only, never a local .build or Package.resolved.
cp "$REPO_ROOT/examples/openapi-service/Package.swift" "$WORKDIR/Package.swift"
cp -R "$REPO_ROOT/examples/openapi-service/Sources" "$WORKDIR/Sources"
python3 - "$WORKDIR/Package.swift" "$MODE" "$PACKAGE_PATH" "$REPO_URL" "$VERSION" "$REVISION" <<'PY'
import json, pathlib, sys
file, mode, local_path, repo, version, revision = sys.argv[1:]
quote = lambda value: json.dumps(value, ensure_ascii=False)
if mode == 'path':
    dependency = '.package(name: "Daylily", path: ' + quote(local_path) + '),'
else:
    # PackageDescription has no name:url:exact: overload.
    requirement = '.exact(' + quote(version.removeprefix('v')) + ')' if mode == 'release' else 'revision: ' + quote(revision)
    dependency = '.package(name: "Daylily", url: ' + quote(repo) + ', ' + requirement + '),'
path = pathlib.Path(file)
text = path.read_text()
start = text.index('        // DAYLILY_DEPENDENCY_START')
end = text.index('        // DAYLILY_DEPENDENCY_END')
path.write_text(text[:start] + '        // DAYLILY_DEPENDENCY_START\n        ' + dependency + '\n' + text[end:])
PY

echo "OpenAPI smoke package: $WORKDIR ($MODE)"
cd "$WORKDIR"
swift package resolve
python3 - "$MODE" "$PACKAGE_PATH" "$VERSION" "$REVISION" "$REPO_URL" <<'PY'
import json, pathlib, subprocess, sys
if sys.argv[1] == 'path':
    result = subprocess.run(['git', '-C', sys.argv[2], 'rev-parse', 'HEAD'], text=True, capture_output=True)
    revision = result.stdout.strip() if result.returncode == 0 else 'unavailable (source directory)'
    print('Daylily path base revision: ' + revision + ' (working tree changes are included)')
else:
    pins = json.loads(pathlib.Path('Package.resolved').read_text())['pins']
    repo = sys.argv[5].rstrip('/')
    identity = repo.rsplit('/', 1)[-1].removesuffix('.git').lower()
    pin = next(p for p in pins if p['identity'].lower() == identity)
    state = pin['state']
    if sys.argv[1] == 'revision' and state['revision'].lower() != sys.argv[4].lower():
        raise SystemExit('Resolved Daylily revision does not match the requested commit')
    if sys.argv[1] == 'release' and state.get('version') != sys.argv[3].removeprefix('v'):
        raise SystemExit('Resolved Daylily version does not match the requested exact release')
    print('Resolved Daylily: ' + json.dumps(state, sort_keys=True))
PY
cp Sources/GeneratedAPI/openapi.json "$WORKDIR/expected-openapi.json"
swift run ExportSchema Sources/GeneratedAPI/openapi.json
if ! cmp -s "$WORKDIR/expected-openapi.json" Sources/GeneratedAPI/openapi.json; then
    echo 'Checked-in openapi.json is stale. Run ExportSchema in examples/openapi-service and commit the updated specification.' >&2
    exit 1
fi
swift build --product App
BIN_PATH="$(swift build --show-bin-path)"
python3 - "$BIN_PATH/App" <<'PY'
import subprocess, sys
subprocess.run([sys.argv[1], '--check'], check=True, timeout=60)
PY
echo "Daylily OpenAPI generation and real HTTP smoke passed ($MODE)."
