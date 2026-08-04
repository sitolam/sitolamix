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
ROUTER_URL="http://127.0.0.1:${ROUTER_PORT}"
CONFIG_DIR="${HOME}/.claude-code-router"
CONFIG="${CONFIG_DIR}/config.json"
OWNED="${CONFIG_DIR}/.ccl-owned"
STATE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/ccl"
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
  # No `-S`: curl's own "Failed to connect" would print before, and read as louder
  # than, the explanation below, which already says everything the user can act on.
  curl -fs --max-time 5 "${LMSTUDIO_URL}/api/v0/models" \
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
        ((.loaded_context_length // .max_context_length) as $ctx
         | if $ctx then ($ctx | tostring) + " ctx" else "? ctx" end),
        (if ((.capabilities // []) | index("tool_use")) then "tools" else "-" end),
        (if .state == "loaded" then "● loaded" else "○ not-loaded" end)
      ]
    | @tsv
  '
}

# The status column goes last on purpose: `column -t` measures width in bytes, so a
# multi-byte ●/○ in any earlier column would throw off the alignment of the rest.
list_models() {
  printf '%s\n' "$1" | column -t -s $'\t' -o '  '
}

validate_model() {
  local rows="$1" id="$2" candidate
  local -a ids=()
  mapfile -t ids < <(printf '%s\n' "$rows" | cut -f1)
  for candidate in "${ids[@]}"; do
    if [[ "$candidate" == "$id" ]]; then
      return 0
    fi
  done
  printf 'ccl: no selectable model with id %s\n' "$id" >&2
  printf 'ccl: available:\n' >&2
  printf '  %s\n' "${ids[@]}" >&2
  exit 1
}

# A loaded model reports the context it was actually loaded with, which is what
# constrains the session. Fall back to the model's ceiling when it is not loaded.
effective_ctx() {
  printf '%s' "$1" | jq -r --arg id "$2" '
    .data[] | select(.id == $id) | (.loaded_context_length // .max_context_length // 0)
  '
}

# A model that is not loaded is loaded on the first request that needs it, at whatever
# context it is configured with in LM Studio rather than the ceiling effective_ctx
# fell back to. That load can take minutes, and by then ccl has exec'd, so Claude Code
# would otherwise just look like it is hanging on the first prompt.
note_not_loaded() {
  local state
  state="$(printf '%s' "$1" | jq -r --arg id "$2" '.data[] | select(.id == $id) | .state')"
  if [[ "$state" == "loaded" ]]; then
    return 0
  fi
  cat >&2 <<EOF
ccl: ${2} is not loaded yet; LM Studio will load it on Claude Code's first request.
     That can take minutes, and looks like a hang until it finishes.
EOF
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

# Claude Code's system prompt and tool definitions run to many thousands of tokens
# before the user types anything, so a small context fails on the very first
# request. Warn loudly but do not block — the user may know something we do not.
warn_small_context() {
  local ctx="$1"
  if (( ctx >= MIN_CONTEXT )); then
    return 0
  fi
  cat >&2 <<EOF
ccl: WARNING — this model's context is ${ctx} tokens, below the ${MIN_CONTEXT} ccl expects.
     Claude Code's system prompt and tool definitions alone will exceed it, so the
     session will most likely fail on the first request.
     Fix: in LM Studio, open the model's settings, raise "Context Length", reload it.
     Continuing anyway.
EOF
}

# The id is column 1 so the selection can be parsed with awk regardless of how
# `column` padded the rest. fzf exits non-zero when the user presses Esc; the
# caller distinguishes that from a real failure by checking for empty output.
pick_model() {
  printf '%s\n' "$1" \
    | column -t -s $'\t' -o '  ' \
    | fzf --height=40% --reverse --no-multi \
          --header='Select an LM Studio model for Claude Code' \
    | awk '{ print $1 }'
}

write_config() {
  local content="$1"
  mkdir -p "$CONFIG_DIR"
  # A config's mere existence doesn't say who wrote it — ccl's own previous output
  # looks identical to a foreign file. The marker is the only reliable signal: its
  # absence means this config predates ccl, so back it up before overwriting it.
  # The backup is write-once. Losing the marker while the backup survives is entirely
  # possible (dotfile cleanup, a restored directory), and copying a second time would
  # put ccl's own generated config over the user's original and destroy it for good.
  if [[ -f "$CONFIG" && ! -f "$OWNED" && ! -f "${CONFIG}.pre-ccl" ]]; then
    cp "$CONFIG" "${CONFIG}.pre-ccl"
    printf 'ccl: backed up your existing router config to %s.pre-ccl\n' "$CONFIG" >&2
  fi
  # `tmp` is deliberately not `local`: if a later command fails under errexit, the
  # EXIT trap below still needs to see it, but errexit unwinds this function's local
  # scope before running the trap, which would otherwise fail with "unbound variable".
  tmp="$(mktemp "${CONFIG_DIR}/.config.json.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  printf '%s\n' "$content" > "$tmp"
  mv -f "$tmp" "$CONFIG"
  trap - EXIT
  touch "$OWNED"
}

router_healthy() {
  curl -fsS --max-time 2 "${ROUTER_URL}/health" >/dev/null 2>&1
}

# `ccr` opens its rotated log file before it can fail, so a router that dies during
# startup — against an occupied port, say — leaves a zero-byte log and no diagnostic
# at all. Its own startup errors go to stdout/stderr instead, which is why
# ensure_router captures those to router-start.log and both files are dumped here.
dump_router_logs() {
  local f newest=""
  local -a logs=()

  if [[ -s "${STATE_DIR}/router-start.log" ]]; then
    logs+=("${STATE_DIR}/router-start.log")
  fi
  # `ccr` rotates with maxFiles:3, and the older two belong to earlier runs that
  # started fine. Dumping all of them would bury this failure under their output.
  for f in "${CONFIG_DIR}"/logs/*.log; do
    if [[ -f "$f" ]] && [[ -z "$newest" || "$f" -nt "$newest" ]]; then
      newest="$f"
    fi
  done
  if [[ -n "$newest" && -s "$newest" ]]; then
    logs+=("$newest")
  fi

  # Emptiness is the common case here, and a header followed by nothing reads as if
  # ccl swallowed the error, so say plainly that there was nothing to show.
  if (( ${#logs[@]} == 0 )); then
    printf 'ccl: the router logged nothing before failing.\n' >&2
    return 0
  fi

  printf 'ccl: last 20 lines of each router log:\n' >&2
  # Redirection order matters: `>&2` first sends tail's real output to our stderr,
  # then `2>/dev/null` only silences tail's own error messages (e.g. a log rotated
  # away under us) so they don't clobber that real output. Swapped, the log content
  # itself would vanish into /dev/null along with tail's errors.
  tail -qn 20 "${logs[@]}" >&2 2>/dev/null || true
}

# The router reads its config once at startup, so a config change means a restart.
# Hashing lets us skip that restart on the common path of relaunching the same model.
ensure_router() {
  local hash_file="${STATE_DIR}/active-config.sha256" want have="" router_pid
  want="$(sha256sum < "$CONFIG" | cut -d' ' -f1)"
  if [[ -f "$hash_file" ]]; then
    have="$(cat "$hash_file")"
  fi

  if [[ "$want" == "$have" ]] && router_healthy; then
    return 0
  fi

  # `ccr stop` SIGTERMs whatever pid is in ~/.claude-code-router/.claude-code-router.pid
  # without checking that it is still the router. That file lives in $HOME, so it
  # survives logout and reboot, after which the pid it names has most likely been
  # reissued to an unrelated process — which `ccr stop` would then kill, silently,
  # since ccl discards its output. A live health check is the only evidence we have
  # that there is a router there at all, so nothing is stopped without one.
  if router_healthy; then
    ccr stop >/dev/null 2>&1 || true
    # `ccr stop` sends SIGTERM and returns immediately; it does not wait for the old
    # router to finish its graceful drain. Starting the new one before the old one has
    # released the port risks either an EADDRINUSE on the new process, or worse: the
    # first health check below being answered by the dying old router, which would make
    # us record the new config's hash against a router that isn't actually serving it.
    for _ in $(seq 1 20); do
      if ! router_healthy; then
        break
      fi
      sleep 0.25
    done
  fi

  mkdir -p "$STATE_DIR"
  # `ccr start` runs the server in the foreground rather than daemonizing itself, and
  # backgrounding it with a bare `&` would still leave it in ccl's process group and
  # session, so it would receive Ctrl-C/SIGHUP along with everything else in the
  # terminal's foreground group. `setsid` gives it its own session so it detaches
  # fully and outlives this shell, the same as ccr's own restart/code/ui subcommands.
  setsid ccr start </dev/null >"${STATE_DIR}/router-start.log" 2>&1 &
  router_pid=$!

  local reason="waited 15s"
  for _ in $(seq 1 30); do
    if router_healthy; then
      # This records the hash of the config ccl just wrote, not necessarily what a
      # router started by hand outside ccl is actually serving.
      printf '%s\n' "$want" > "$hash_file"
      return 0
    fi
    # A router that refuses to start does so at once, and waiting out the full timeout
    # for a process that is already gone helps nobody. The health check comes first so
    # that a router which came up and was reaped in the same tick still counts as up.
    if ! kill -0 "$router_pid" 2>/dev/null; then
      reason="the router process exited during startup"
      break
    fi
    sleep 0.5
  done

  printf 'ccl: the router never became healthy at %s (%s)\n' "$ROUTER_URL" "$reason" >&2
  dump_router_logs
  exit 1
}

main() {
  local mode="launch" model=""
  local -a claude_args=()

  while (( $# )); do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --list) mode="list"; shift ;;
      --print-config) mode="print-config"; shift ;;
      --) shift; claude_args=("$@"); break ;;
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

  local json rows
  json="$(models_json)"
  # Every mode needs the same candidate rows, and an empty set is a dead end on all
  # of them — computing it here is what makes that true of the picker too, which used
  # to open empty on a fresh LM Studio and exit 0 without a word when dismissed.
  rows="$(candidates "$json")"
  if [[ -z "$rows" ]]; then
    die "LM Studio returned no chat-capable models (embeddings models cannot be used).
     Load a model in LM Studio first."
  fi

  if [[ "$mode" == "list" ]]; then
    list_models "$rows"
    exit 0
  fi

  if [[ "$mode" == "print-config" && -z "$model" ]]; then
    die "--print-config needs a model id (see: ccl --list)"
  fi

  # `pick_model` runs in a command substitution, so an `exit` inside it would only
  # end the subshell. Detect cancellation by the empty result instead.
  if [[ -z "$model" ]]; then
    model="$(pick_model "$rows")" || true
    if [[ -z "$model" ]]; then
      exit 0
    fi
  fi

  validate_model "$rows" "$model"

  local ctx config
  ctx="$(effective_ctx "$json" "$model")"
  # A model reporting neither a loaded nor a maximum context leaves nothing to size
  # the long-context threshold against, and the arithmetic below would fail with a
  # raw bash error rather than anything the user could act on.
  if (( ctx == 0 )); then
    die "LM Studio reports no context length for ${model}.
     Load the model in LM Studio, then try again."
  fi
  config="$(gen_config "$model" "$ctx")"

  if [[ "$mode" == "print-config" ]]; then
    printf '%s\n' "$config"
    exit 0
  fi

  warn_small_context "$ctx"
  note_not_loaded "$json" "$model"
  write_config "$config"
  ensure_router

  printf 'ccl: %s via the router on %s\n' "$model" "$ROUTER_URL" >&2
  exec ccr code "${claude_args[@]}"
}

main "$@"
