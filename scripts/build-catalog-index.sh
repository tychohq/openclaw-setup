#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCHES_DIR="$REPO_ROOT/shared/patches/patches"
OUT="$REPO_ROOT/web/catalog.json"

ls "$PATCHES_DIR"/*.yaml 2>/dev/null \
  | xargs -n1 basename \
  | sed 's/\.yaml$//' \
  | jq -R -s 'split("\n") | map(select(. != ""))' \
  > "$OUT"

echo "catalog.json written with $(jq length "$OUT") entries → $OUT"
