#!/usr/bin/env bash
# OctoPrint CLI for the Prusa MINI+ at http://octoprint. The API key comes from 1Password
# and is never printed or written to disk.
#   octo.sh status | files [N] | info NAME | upload FILE [--select] | snapshot OUT.jpg
#   octo.sh print NAME --confirm | cancel --confirm | pause | resume
set -euo pipefail
set +x

OCTO_URL="${OCTO_URL:-http://octoprint}"
OP_REF="op://Private/octoprint/Agent API Key"
OP_ACCOUNT="skram.1password.com"
SOCK="${TMPDIR:-/tmp}/clawdbot-tmux-sockets/clawdbot-op.sock"
SESSION="op-work"

# The one-password skill runs every `op` call inside one persistent tmux session.
# Outside tmux, re-run this script there and relay its output and exit code.
if [ -z "${TMUX:-}" ]; then
  args=("$@")
  if [ "${1:-}" = upload ] && [ -n "${2:-}" ]; then
    args[1]="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
  fi
  mkdir -p "$(dirname "$SOCK")"
  tmux -S "$SOCK" has-session -t "$SESSION" 2>/dev/null || tmux -S "$SOCK" new -d -s "$SESSION"
  out="$(mktemp "${TMPDIR:-/tmp}/octo.XXXXXX")"
  rm -f "$out.rc"
  self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  inner="TMUX=1 $(printf '%q ' "$self" "${args[@]}") > $(printf '%q' "$out") 2>&1; echo \$? > $(printf '%q' "$out.rc")"
  # bash -c: the pane's shell may be fish, which has no $?
  tmux -S "$SOCK" send-keys -t "$SESSION:" -- "bash -c $(printf '%q' "$inner")" Enter
  for _ in $(seq 1 300); do [ -s "$out.rc" ] && break; sleep 1; done
  cat "$out"
  rc="$(cat "$out.rc" 2>/dev/null || echo 124)"
  rm -f "$out" "$out.rc"
  exit "$rc"
fi

KEY="$(OP_BIOMETRIC_UNLOCK_ENABLED=true op read --account "$OP_ACCOUNT" "$OP_REF")"
api() { curl -sS -m "${TIMEOUT:-15}" -H "X-Api-Key: $KEY" "$@"; }
need_confirm() { [ "${1:-}" = --confirm ] || { echo "refusing: pass --confirm only after the user explicitly asked for this" >&2; exit 2; }; }
job() { api -H "Content-Type: application/json" -X POST -d "$1" -o /dev/null -w "http:%{http_code}\n" "$OCTO_URL/api/job"; }

cmd="${1:-status}"
shift || true
case "$cmd" in
  status)
    api "$OCTO_URL/api/connection" | jq -c '{connection: .current.state, port: .current.port}'
    # /api/printer is 409 while the printer is disconnected
    p="$(api -w '\n%{http_code}' "$OCTO_URL/api/printer?exclude=sd")"
    if [ "$(tail -n1 <<<"$p")" = 200 ]; then
      sed '$d' <<<"$p" | jq -c '{state: .state.text, hotend: .temperature.tool0, bed: .temperature.bed}'
    else
      echo "printer: not operational (http $(tail -n1 <<<"$p"))"
    fi
    api "$OCTO_URL/api/job" | jq -c '{job: .job.file.name, state, progress: .progress.completion, elapsed_s: .progress.printTime, left_s: .progress.printTimeLeft}'
    ;;
  files)
    api "$OCTO_URL/api/files/local?recursive=true" | jq -r --argjson n "${1:-15}" \
      '[.files[] | select(.type == "machinecode")] | sort_by(-.date) | .[:$n][] | [.path, .size, (.date | todate), (.gcodeAnalysis.estimatedPrintTime // "?" | tostring)] | @tsv'
    ;;
  info)
    api "$OCTO_URL/api/files/local/${1:?NAME}" | jq '{path, size, date: (.date | todate), est_s: .gcodeAnalysis.estimatedPrintTime, filament_mm: .gcodeAnalysis.filament.tool0.length, prints}'
    ;;
  upload)
    f="${1:?FILE}"
    sel=false; [ "${2:-}" = --select ] && sel=true
    TIMEOUT=300 api -F "file=@$f" -F "select=$sel" -F "print=false" "$OCTO_URL/api/files/local" | jq -c '{done, path: .files.local.path}'
    remote="$(api "$OCTO_URL/api/files/local/$(basename "$f")" | jq -r .size)"
    local_size="$(wc -c <"$f" | tr -d ' ')"
    [ "$remote" = "$local_size" ] && echo "verified: $remote bytes" || { echo "size mismatch: local $local_size remote $remote" >&2; exit 1; }
    ;;
  print)
    name="${1:?NAME}"; need_confirm "${2:-}"
    api -H "Content-Type: application/json" -X POST -d '{"command":"select","print":true}' -o /dev/null -w "http:%{http_code}\n" "$OCTO_URL/api/files/local/$name"
    ;;
  cancel) need_confirm "${1:-}"; job '{"command":"cancel"}' ;;
  pause) job '{"command":"pause","action":"pause"}' ;;
  resume) job '{"command":"pause","action":"resume"}' ;;
  snapshot)
    o="${1:?OUT.jpg}"
    ct="$(api -o "$o" -w '%{http_code} %{content_type}' "$OCTO_URL/webcam/?action=snapshot")"
    case "$ct" in 200\ image/*) echo "saved $o" ;; *) rm -f "$o"; echo "no webcam image ($ct)" >&2; exit 1 ;; esac
    ;;
  *) sed -n '2,5p' "$0"; exit 2 ;;
esac
