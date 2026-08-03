# shellcheck shell=bash
#
# ccl — launch Claude Code against a model served by LM Studio.
#
# LM Studio speaks the OpenAI API; Claude Code speaks Anthropic's. claude-code-router
# sits between the two and translates. This script picks a model, points the router at
# it, makes sure the router is up, then hands off to Claude Code.
#
# NOTE: writeShellApplication supplies the shebang and `set -euo pipefail`.

LMSTUDIO_URL="${CCL_LMSTUDIO_URL:-http://127.0.0.1:1234}"
ROUTER_PORT="${CCL_ROUTER_PORT:-4141}"
# Not read until the router lifecycle lands (a later task); shellcheck can't see that
# from this file alone.
# shellcheck disable=SC2034
ROUTER_URL="http://127.0.0.1:${ROUTER_PORT}"
CONFIG_DIR="${HOME}/.claude-code-router"
# Not read until config generation lands (a later task).
# shellcheck disable=SC2034
CONFIG="${CONFIG_DIR}/config.json"
# Not read until the router lifecycle lands (a later task).
# shellcheck disable=SC2034
STATE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/ccl"
# Not read until the context guard lands (a later task).
# shellcheck disable=SC2034
MIN_CONTEXT=32768

die() {
  printf 'ccl: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
ccl — launch Claude Code against an LM Studio model

Usage:
  ccl                            pick a model interactively, then launch
  ccl <model-id>                 launch with a specific model
  ccl --list                     list selectable models and exit
  ccl --print-config <model-id>  print the router config that would be written
  ccl [model-id] -- <args...>    forward args after -- to claude

Environment:
  CCL_LMSTUDIO_URL   LM Studio base URL (default http://127.0.0.1:1234)
  CCL_ROUTER_PORT    claude-code-router port (default 4141)
EOF
}

models_json() {
  curl -fsS --max-time 5 "${LMSTUDIO_URL}/api/v0/models" \
    || die "LM Studio is not answering at ${LMSTUDIO_URL}.
     Start LM Studio and turn on the local server (Developer tab -> Status: Running)."
}

# TSV rows for every model that can serve chat. Embeddings models are dropped:
# they have no chat endpoint, so offering them would only produce confusing errors.
candidates() {
  printf '%s' "$1" | jq -r '
    .data[]
    | select(.type != "embeddings")
    | [ .id,
        (((.loaded_context_length // .max_context_length) | tostring) + " ctx"),
        (if ((.capabilities // []) | index("tool_use")) then "tools" else "-" end),
        (if .state == "loaded" then "● loaded" else "○ not-loaded" end)
      ]
    | @tsv
  '
}

# The status column goes last on purpose: `column -t` measures width in bytes, so a
# multi-byte ●/○ in any earlier column would throw off the alignment of the rest.
list_models() {
  local rows
  rows="$(candidates "$1")"
  if [[ -z "$rows" ]]; then
    die "LM Studio returned no chat-capable models (embeddings models cannot be used).
     Load a model in LM Studio first."
  fi
  printf '%s\n' "$rows" | column -t -s $'\t' -o '  '
}

validate_model() {
  local json="$1" id="$2" ok
  ok="$(printf '%s' "$json" | jq -r --arg id "$id" '
    [ .data[] | select(.type != "embeddings") | .id ] | index($id) != null
  ')"
  if [[ "$ok" != "true" ]]; then
    printf 'ccl: no selectable model with id %s\n' "$id" >&2
    printf 'ccl: available:\n' >&2
    candidates "$json" | cut -f1 | sed 's/^/  /' >&2
    exit 1
  fi
}

# A loaded model reports the context it was actually loaded with, which is what
# constrains the session. Fall back to the model's ceiling when it is not loaded.
effective_ctx() {
  printf '%s' "$1" | jq -r --arg id "$2" '
    .data[] | select(.id == $id) | (.loaded_context_length // .max_context_length)
  '
}

gen_config() {
  local model="$1" ctx="$2"
  jq -n \
    --arg model "$model" \
    --arg url "${LMSTUDIO_URL}/v1/chat/completions" \
    --argjson port "$ROUTER_PORT" \
    --argjson threshold "$(( ctx * 60 / 100 ))" \
    '{
      HOST: "127.0.0.1",
      PORT: $port,
      Providers: [ {
        name: "lmstudio",
        api_base_url: $url,
        api_key: "lm-studio",
        models: [ $model ]
      } ],
      Router: {
        default: "lmstudio,\($model)",
        background: "lmstudio,\($model)",
        think: "lmstudio,\($model)",
        longContext: "lmstudio,\($model)",
        longContextThreshold: $threshold
      }
    }'
}

main() {
  local mode="launch" model=""

  while (( $# )); do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --list) mode="list"; shift ;;
      --print-config) mode="print-config"; shift ;;
      -*) die "unknown flag: $1 (use -- to pass flags through to claude)" ;;
      *)
        if [[ -n "$model" ]]; then
          die "more than one model id given: $model, $1"
        fi
        model="$1"
        shift
        ;;
    esac
  done

  local json
  json="$(models_json)"

  if [[ "$mode" == "list" ]]; then
    list_models "$json"
    exit 0
  fi

  if [[ "$mode" == "print-config" && -z "$model" ]]; then
    die "--print-config needs a model id (see: ccl --list)"
  fi

  validate_model "$json" "$model"

  local ctx config
  ctx="$(effective_ctx "$json" "$model")"
  config="$(gen_config "$model" "$ctx")"

  if [[ "$mode" == "print-config" ]]; then
    printf '%s\n' "$config"
    exit 0
  fi

  die "interactive launch is not implemented yet"
}

main "$@"
