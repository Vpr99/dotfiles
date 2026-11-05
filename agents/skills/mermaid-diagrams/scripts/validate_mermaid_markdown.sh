#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <markdown-file>" >&2
  exit 2
fi

md_file="$1"
# Pinned so a new mermaid-cli major cannot silently change the oracle.
# mermaid-cli 12.0.0 declares mermaid ^12.0.0 (GitHub renders 12.x);
# set MERMAID_CLI_VERSION=11.17.0 to check a v11 host (mermaid ^11.14.0).
cli_version="${MERMAID_CLI_VERSION:-12.0.0}"
if [[ ! -f "$md_file" ]]; then
  echo "MERMAID_VALIDATE_FAIL reason=file_not_found path=$md_file" >&2
  exit 2
fi

if ! grep -Eq -e '^```mermaid' -- "$md_file"; then
  echo "MERMAID_VALIDATE_OK blocks=0 rendered=0 note=no_mermaid_block"
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

set +e
validate_output="$(npx -y "@mermaid-js/mermaid-cli@$cli_version" \
  -i "$md_file" \
  -o "$tmp_dir/out.md" \
  -a "$tmp_dir/art" \
  -q 2>&1)"
validate_code=$?
set -e

block_count="$(grep -Ec -e '^```mermaid' -- "$md_file")"

if [[ $validate_code -ne 0 ]]; then
  echo "MERMAID_VALIDATE_FAIL blocks=$block_count cli=$cli_version" >&2
  echo "$validate_output" >&2
  exit $validate_code
fi

rendered_count="$(find "$tmp_dir/art" -type f | wc -l | tr -d ' ')"
echo "MERMAID_VALIDATE_OK blocks=$block_count rendered=$rendered_count cli=$cli_version"
