#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

exec "$SCRIPT_DIR/template-smoke-test.sh" \
    --name "commerce API example" \
    --template-dir "$REPO_ROOT/examples/commerce-api" \
    "$@"
