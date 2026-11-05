#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp)"
trap 'rm -f "$fixture"' EXIT

printf '%s\n' \
  '```mermaid' \
  'flowchart LR' \
  '  A01[01] --> A02[02] --> A03[03] --> A04[04] --> A05[05] --> A06[06] --> A07[07] --> A08[08] --> A09[09] --> A10[10] --> A11[11] --> A12[12] --> A13[13] --> A14[14] --> A15[15] --> A16[16] --> A17[17]' \
  '```' > "$fixture"

output="$("$script_dir/assess_mermaid_density.sh" "$fixture")"

grep -Fq 'MERMAID_DENSITY block=1 nodes=17 edges=16 long_labels=0 risk=high' <<< "$output"
grep -Fq 'MERMAID_DENSITY_WARN blocks=1' <<< "$output"

printf '%s\n' \
  '```mermaid' \
  'flowchart LR' \
  '  A --> B --> C' \
  '```' > "$fixture"

output="$("$script_dir/assess_mermaid_density.sh" "$fixture")"

grep -Fq 'MERMAID_DENSITY block=1 nodes=3 edges=2 long_labels=0 risk=low' <<< "$output"
grep -Fq 'MERMAID_DENSITY_OK blocks=1' <<< "$output"

echo "MERMAID_DENSITY_TEST_OK"
