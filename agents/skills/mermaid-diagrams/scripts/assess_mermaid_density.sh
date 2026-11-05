#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <markdown-file>" >&2
  exit 2
fi

md_file="$1"
if [[ ! -f "$md_file" ]]; then
  echo "MERMAID_DENSITY_FAIL reason=file_not_found path=$md_file" >&2
  exit 2
fi

awk '
BEGIN {
  in_block = 0
  idx = 0
}
/^```mermaid[[:space:]]*$/ {
  in_block = 1
  idx++
  block[idx] = ""
  next
}
/^```[[:space:]]*$/ {
  if (in_block == 1) {
    in_block = 0
  }
  next
}
{
  if (in_block == 1) {
    block[idx] = block[idx] $0 "\n"
  }
}
END {
  if (idx == 0) {
    print "MERMAID_DENSITY_OK blocks=0 note=no_mermaid_block"
    exit 0
  }

  has_warn = 0

  for (i = 1; i <= idx; i++) {
    node_count = 0
    edge_count = 0
    long_label_count = 0
    edge_style_present = 0
    colored_node_style_present = 0

    n = split(block[i], lines, "\n")
    for (j = 1; j <= n; j++) {
      line = lines[j]

      is_frontmatter_delimiter = (line ~ /^[[:space:]]*---[[:space:]]*$/)
      if (!is_frontmatter_delimiter) {
        edge_line = line
        while (match(edge_line, /(-[.][^.]*[.]->)|(-[.]->)|(--+>)|(==+>)|(---)|(===)/)) {
          edge_count++
          edge_line = substr(edge_line, RSTART + RLENGTH)
        }
      }

      node_line = line
      while (match(node_line, /([A-Za-z_][A-Za-z0-9_-]*[[:space:]]*\[)|([A-Za-z_][A-Za-z0-9_-]*[[:space:]]*\()|([A-Za-z_][A-Za-z0-9_-]*[[:space:]]*\{)/)) {
        node_token = substr(node_line, RSTART, RLENGTH)
        sub(/[[:space:]]*\[$/, "", node_token)
        sub(/[[:space:]]*\($/, "", node_token)
        sub(/[[:space:]]*\{$/, "", node_token)
        node_key = i SUBSEP node_token
        if (!(node_key in seen_node)) {
          seen_node[node_key] = 1
          node_count++
        }
        node_line = substr(node_line, RSTART + RLENGTH)
      }

      if (!is_frontmatter_delimiter && line ~ /(-[.][^.]*[.]->)|(-[.]->)|(--+>)|(==+>)|(---)|(===)/) {
        endpoint_line = line
        gsub(/\|[^|]*\|/, "", endpoint_line)
        gsub(/-[.][^.]*[.]->/, " @ ", endpoint_line)
        gsub(/-[.]->/, " @ ", endpoint_line)
        gsub(/--[[:space:]]+[^-]*[[:space:]]+-->/, " @ ", endpoint_line)
        gsub(/--+>|==+>|---|===/, " @ ", endpoint_line)
        while (gsub(/\[[^][]*\]/, "", endpoint_line) > 0) {}
        while (gsub(/\([^()]*\)/, "", endpoint_line) > 0) {}
        while (gsub(/\{[^{}]*\}/, "", endpoint_line) > 0) {}

        endpoint_count = split(endpoint_line, endpoints, "@")
        for (endpoint_index = 1; endpoint_index <= endpoint_count; endpoint_index++) {
          endpoint = endpoints[endpoint_index]
          while (match(endpoint, /[A-Za-z_][A-Za-z0-9_-]*/)) {
            endpoint_id = substr(endpoint, RSTART, RLENGTH)
            node_key = i SUBSEP endpoint_id
            if (!(node_key in seen_node)) {
              seen_node[node_key] = 1
              node_count++
            }
            endpoint = substr(endpoint, RSTART + RLENGTH)
          }
        }
      }

      if (line ~ /linkStyle[[:space:]]+default[[:space:]]+stroke:/) {
        edge_style_present = 1
      }

      if (line ~ /style[[:space:]]+[A-Za-z0-9_,]+[[:space:]]+fill:#/ || line ~ /classDef[[:space:]]+[A-Za-z0-9_]+[[:space:]]+fill:#/) {
        colored_node_style_present = 1
      }

      line_copy = line
      while (match(line_copy, /"[^"]+"/)) {
        label = substr(line_copy, RSTART + 1, RLENGTH - 2)
        gsub(/<[^>]+>/, "", label)
        gsub(/&nbsp;/, " ", label)
        gsub(/[[:space:]]+/, " ", label)
        if (length(label) > 40) {
          long_label_count++
        }
        line_copy = substr(line_copy, RSTART + RLENGTH)
      }
    }

    risk = "low"
    if (node_count >= 12 || edge_count >= 16 || long_label_count >= 4) {
      risk = "high"
      has_warn = 1
    } else if (node_count >= 9 || edge_count >= 12 || long_label_count >= 2) {
      risk = "medium"
      has_warn = 1
    }

    edge_style = (edge_style_present == 1) ? "present" : "absent"
    contrast_risk = "low"
    if (colored_node_style_present == 1 && edge_style_present == 0) {
      contrast_risk = "high"
      has_warn = 1
    }

    printf "MERMAID_DENSITY block=%d nodes=%d edges=%d long_labels=%d risk=%s edge_style=%s contrast_risk=%s\n", i, node_count, edge_count, long_label_count, risk, edge_style, contrast_risk
  }

  if (has_warn == 1) {
    printf "MERMAID_DENSITY_WARN blocks=%d\n", idx
  } else {
    printf "MERMAID_DENSITY_OK blocks=%d\n", idx
  }
}
' "$md_file"
