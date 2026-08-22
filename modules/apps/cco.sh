# shellcheck shell=bash
#
# cco — launch Claude Code against the local OmniRoute gateway.
#
# OmniRoute speaks Anthropic's Messages API natively on /v1/messages, so unlike
# ccl there is nothing to translate: the whole job is pointing Claude Code at
# the gateway root and handing over. Claude Code appends /v1/messages itself,
# so ANTHROPIC_BASE_URL must NOT carry a /v1 suffix.
#
# NOTE: writeShellApplication supplies the shebang and `set -euo pipefail`, and
# the Nix module seeds CCO_BASE_URL from services.omniroute.port.

TOKEN_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/omniroute/api-key"

# Claude Code refuses to start at its own login gate when no token is present,
# and never gets far enough to discover that the gateway does not want one. A
# sentinel satisfies the gate; an open backend ignores the value. Mirrors what
# `omniroute launch` does upstream.
SENTINEL="omniroute-no-auth"

model="${CCO_MODEL:-}"

die() {
  printf 'cco: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
cco — launch Claude Code against the local OmniRoute gateway

Usage:
  cco [args...]              launch, forwarding args to claude
  cco --model <id> [args...] launch pinned to one gateway model
  cco --list                 list the models the gateway is serving
  cco --print-env            print the environment claude would be launched with

Environment:
  CCO_BASE_URL       gateway root, no /v1 suffix (default http://127.0.0.1:20128)
  CCO_MODEL          default for --model
  OMNIROUTE_API_KEY  bearer token; otherwise read from
                     ~/.config/omniroute/api-key, otherwise a no-auth sentinel
EOF
}

# The gateway is open by default (REQUIRE_API_KEY=false), so a token is only
# needed once you turn on the dashboard password or key enforcement. Reading it
# from a file keeps it out of both the store and the shell environment.
resolve_token() {
  if [ -n "${OMNIROUTE_API_KEY:-}" ]; then
    printf '%s' "${OMNIROUTE_API_KEY}"
  elif [ -r "${TOKEN_FILE}" ]; then
    tr -d '[:space:]' <"${TOKEN_FILE}"
  else
    printf '%s' "${SENTINEL}"
  fi
}

require_gateway() {
  curl -fs --max-time 5 "${CCO_BASE_URL}/api/monitoring/health" >/dev/null \
    || die "OmniRoute is not answering at ${CCO_BASE_URL}.
     It runs as a container unit: systemctl status docker-omniroute
     Logs:                        journalctl -u docker-omniroute -e"
}

list_models() {
  curl -fs --max-time 10 \
    -H "Authorization: Bearer $(resolve_token)" \
    "${CCO_BASE_URL}/v1/models" \
    | jq -r '.data[].id' \
    | sort
}

args=()
action=launch

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --list)
      action=list
      shift
      ;;
    --print-env)
      action=print-env
      shift
      ;;
    --model)
      [ $# -ge 2 ] || die "--model needs a model id (see: cco --list)"
      model="$2"
      shift 2
      ;;
    --)
      shift
      args+=("$@")
      break
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

if [ "${action}" = "list" ]; then
  require_gateway
  list_models
  exit 0
fi

require_gateway

# Drop every inherited ANTHROPIC_* first. A stale ANTHROPIC_API_KEY in the shell
# would otherwise shadow the bearer token below, and a leftover base URL from
# another launcher would silently win.
for name in $(compgen -v ANTHROPIC_ || true); do
  unset "${name}"
done

token="$(resolve_token)"
export ANTHROPIC_BASE_URL="${CCO_BASE_URL}"
export ANTHROPIC_AUTH_TOKEN="${token}"
# Makes Claude Code fetch /v1/models from the gateway and offer those ids in
# /model, instead of assuming Anthropic's own catalog. Without it the default
# model id it sends is one the gateway has to guess at.
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
# Gateway models are not all 200k; compact before the smaller ones truncate.
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=190000
# Deliberately left unset unless asked for: with discovery on, Claude Code picks
# a real gateway model on its own, and pinning one here would freeze that choice.
if [ -n "${model}" ]; then
  export ANTHROPIC_MODEL="${model}"
fi

if [ "${action}" = "print-env" ]; then
  shown="<redacted>"
  if [ "${token}" = "${SENTINEL}" ]; then
    shown="${SENTINEL}"
  fi
  printf 'ANTHROPIC_BASE_URL=%s\n' "${ANTHROPIC_BASE_URL}"
  printf 'ANTHROPIC_AUTH_TOKEN=%s\n' "${shown}"
  printf 'CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=%s\n' "${CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY}"
  printf 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=%s\n' "${CLAUDE_CODE_AUTO_COMPACT_WINDOW}"
  printf 'ANTHROPIC_MODEL=%s\n' "${ANTHROPIC_MODEL:-<unset — gateway discovery picks>}"
  exit 0
fi

exec claude "${args[@]}"
