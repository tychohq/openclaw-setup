#!/usr/bin/env bash
set -euo pipefail
TEST_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_AREA="$(mktemp -d /private/tmp/pr6-sandbox.XXXXXX)"
trap 'rm -rf "$TEST_AREA"' EXIT
mkdir -p "$TEST_AREA/home"
TEST_SHELL="${1:-/bin/bash}"
# Apple's Bash 3.2 can create heredoc files in the working directory.
cd "$TEST_AREA"
env -i HOME="$TEST_AREA/home" TMPDIR="$TEST_AREA" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  MACOS_TEST_BASH="$TEST_SHELL" \
  /usr/bin/sandbox-exec -p "(version 1) (allow default) (deny network*) (deny file-write*) (allow file-write* (subpath \"$TEST_AREA\") (literal \"/dev/null\"))" \
  "$TEST_SHELL" "$TEST_ROOT/macos/tests/test-setup-profiles.sh"
