#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/smoke-common.sh"
MODE=path VERSION= REVISION= BRANCH=main KEEP_WORKDIR=0 WORKDIR=
PROFILE=persistent-commerce
REPO_URL=https://github.com/sinduke/Daylily.git
PACKAGE_PATH="$REPO_ROOT"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep) KEEP_WORKDIR=1; shift;;
        -h|--help)
            echo 'Usage: persistent-consumer-smoke-test.sh [--mode path|revision|release] [--revision SHA] [--version VERSION] [--repo-url URL] [--package-path PATH] [--workdir PATH] [--keep]'
            exit 0;;
        --mode|--revision|--version|--repo-url|--package-path|--workdir|--branch)
            smoke_require_value "$@"
            case "$1" in
                --mode) MODE="$2";; --revision) REVISION="$2";; --version) VERSION="$2";;
                --repo-url) REPO_URL="$2";; --package-path) PACKAGE_PATH="$2";;
                --workdir) WORKDIR="$2";; --branch) BRANCH="$2";;
            esac
            shift 2;;
        *) echo "Unknown option: $1" >&2; exit 2;;
    esac
done
smoke_dependency
smoke_require_tools
smoke_prepare_workdir
trap smoke_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
python3 - "$REPO_ROOT" "$WORKDIR" "$DAYLILY_DEPENDENCY" <<'PY'
import pathlib, re, shutil, sys
root, work = map(pathlib.Path, sys.argv[1:3])
dependency = sys.argv[3]
for src, dest in [(root / 'examples/commerce-api/persistent', work),
                  (root / 'examples/commerce-api', work / 'CommerceAPI')]:
    dest.mkdir(parents=True, exist_ok=True)
    for name in ('Sources', 'Tests'):
        if (src / name).is_dir(): shutil.copytree(src / name, dest / name)
    text = (src / 'Package.swift').read_text()
    text, count = re.subn(r'\.package\(name: "Daylily", path: "[^"]*"\)', lambda _: dependency, text)
    assert count == 1, 'Expected one framework dependency'
    if dest == work:
        text = text.replace('.package(name: "DaylilyCommerceAPI", path: "..")',
                            '.package(name: "DaylilyCommerceAPI", path: "CommerceAPI")')
    (dest / 'Package.swift').write_text(text)
    if (src / 'Package.resolved').is_file(): shutil.copy2(src / 'Package.resolved', dest / 'Package.resolved')
PY
(
    cd "$WORKDIR"
    swift package resolve
    smoke_record_dependency
    swift build --jobs 4 --product PersistentCommerce
    swift test --jobs 4
)
echo "Persistent commerce consumer passed ($MODE); database behavior is verified by the deployment harness."
