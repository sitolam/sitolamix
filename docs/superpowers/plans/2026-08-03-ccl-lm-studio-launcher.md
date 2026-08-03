# ccl — LM Studio Launcher for Claude Code: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `ccl` command that lists the models LM Studio has loaded, lets the user pick one, and drops them into a real Claude Code session backed by that model.

**Architecture:** A bash script (`modules/apps/ccl.sh`) wrapped by a Nix module (`modules/apps/ccl.nix`) using `pkgs.writeShellApplication`. The script queries LM Studio's `/api/v0/models`, writes a `claude-code-router` config pointing at the chosen model, ensures the router is healthy on `:4141`, then `exec`s `ccr code`. claude-code-router performs the Anthropic↔OpenAI translation; we own only the launcher.

**Tech Stack:** Nix (NixOS module + home-manager), bash, `jq`, `curl`, `fzf`, `util-linux` (`column`), `claude-code-router` 2.0.0, `claude-code`.

**Spec:** `docs/superpowers/specs/2026-08-03-ccl-lm-studio-claude-code-launcher-design.md`

## Global Constraints

- LM Studio base URL defaults to `http://127.0.0.1:1234`, overridable via `CCL_LMSTUDIO_URL`.
- Router port defaults to `4141`, overridable via `CCL_ROUTER_PORT`.
- Router config path is `~/.claude-code-router/config.json`. It is **runtime-owned by `ccl`**, never declared through `home.file` or `xdg.configFile`.
- Minimum acceptable context is `32768` tokens. Below this, warn and continue — never block.
- `longContextThreshold` is a **number**, computed as 60% of effective context, rounded down.
- Provider name in the router config is exactly `lmstudio`. Router role values are `"lmstudio,<model-id>"`.
- Models with `type == "embeddings"` are always excluded — they cannot serve chat completions.
- Effective context = `loaded_context_length` when present, else `max_context_length`.
- Module follows the repo convention: `options.apps.ccl.enable = lib.mkEnableOption ...`, body under `config = lib.mkIf cfg.enable { home.extraOptions = { pkgs, ... }: { ... }; }`.
- **`writeShellApplication` already emits the shebang and `set -euo pipefail`.** `ccl.sh` must contain neither. It starts with `# shellcheck shell=bash` so editors and linters know the dialect.
- **`writeShellApplication` runs shellcheck at build time.** A shellcheck failure fails `nix build`. This is the primary automated gate for every task.
- **`errexit` hazard:** never write `[[ cond ]] && action` as a standalone statement — when the test is false the statement returns non-zero and `errexit` kills the script. Always use a full `if` block.

---

## File Structure

| File | Responsibility |
|---|---|
| `modules/apps/ccl.sh` (create) | All logic: discovery, filtering, picking, config generation, router lifecycle, exec. |
| `modules/apps/ccl.nix` (create) | Nix module: `apps.ccl.enable` option, `writeShellApplication` wrapper, runtime deps, `CLAUDE_PATH` pinning. |
| `modules/suites/ai.nix` (modify) | Set `apps.ccl.enable = true` — `ccl` is useless without LM Studio, so it ships with that suite. |
| `README.md` (modify) | New `## 🤖 Local models (ccl)` section following the existing rclone section's shape. |

## Test Fixture

Several tasks verify behavior against a deterministic fixture rather than live LM Studio. Create it once, in the scratchpad (**not** committed):

```bash
mkdir -p /tmp/ccl-fixture/api/v0
cat > /tmp/ccl-fixture/api/v0/models <<'EOF'
{
  "data": [
    { "id": "big-model-70b", "object": "model", "type": "llm", "publisher": "acme",
      "arch": "llama", "compatibility_type": "gguf", "quantization": "Q4_K_M",
      "state": "loaded", "max_context_length": 131072,
      "loaded_context_length": 65536, "capabilities": ["tool_use"] },
    { "id": "small-ctx-7b", "object": "model", "type": "llm", "publisher": "acme",
      "arch": "qwen", "compatibility_type": "gguf", "quantization": "Q4_K_M",
      "state": "loaded", "max_context_length": 32768,
      "loaded_context_length": 4096, "capabilities": ["tool_use"] },
    { "id": "vision-27b", "object": "model", "type": "vlm", "publisher": "acme",
      "arch": "gemma", "compatibility_type": "gguf", "quantization": "Q4_K_M",
      "state": "not-loaded", "max_context_length": 8192 },
    { "id": "nomic-embed", "object": "model", "type": "embeddings", "publisher": "nomic-ai",
      "arch": "nomic-bert", "compatibility_type": "gguf", "quantization": "Q4_K_M",
      "state": "not-loaded", "max_context_length": 2048 }
  ],
  "object": "list"
}
EOF
```

Serve it in a background shell for the duration of a task's verification:

```bash
(cd /tmp/ccl-fixture && python3 -m http.server 8199 >/dev/null 2>&1 &)
```

Then run `ccl` with `CCL_LMSTUDIO_URL=http://127.0.0.1:8199`. Kill it with `pkill -f "http.server 8199"` when done.

The fixture deliberately covers: a healthy loaded model, a loaded model with a too-small context, an unloaded model with no `loaded_context_length` and no `capabilities` key, and an embeddings model that must never appear.

---

### Task 1: Module skeleton, model discovery, and `--list`

**Files:**
- Create: `modules/apps/ccl.sh`
- Create: `modules/apps/ccl.nix`
- Modify: `modules/suites/ai.nix`

**Interfaces:**
- Consumes: nothing.
- Produces: `modules/apps/ccl.sh` shell functions used by every later task —
  - `die <msg...>` → prints `ccl: <msg>` to stderr, exits 1.
  - `models_json` → stdout: raw JSON body from `${LMSTUDIO_URL}/api/v0/models`.
  - `candidates <json>` → stdout: TSV rows, columns `id`, `<n> ctx`, `tools|-`, `● loaded|○ not-loaded`.
  - `list_models <json>` → stdout: `candidates` piped through `column -t`.
  - Globals: `LMSTUDIO_URL`, `ROUTER_PORT`, `ROUTER_URL`, `CONFIG_DIR`, `CONFIG`, `STATE_DIR`, `MIN_CONTEXT`.

- [ ] **Step 1: Write `modules/apps/ccl.sh`**

```bash
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

main() {
  local mode="launch"

  while (( $# )); do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --list) mode="list"; shift ;;
      *) die "unknown argument: $1" ;;
    esac
  done

  local json
  json="$(models_json)"

  if [[ "$mode" == "list" ]]; then
    list_models "$json"
    exit 0
  fi

  die "interactive launch is not implemented yet"
}

main "$@"
```

- [ ] **Step 2: Write `modules/apps/ccl.nix`**

```nix
{ config, lib, ... }:
let
  cfg = config.apps.ccl;
in
{
  options.apps.ccl.enable = lib.mkEnableOption "ccl (launch Claude Code against an LM Studio model)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      let
        ccl = pkgs.writeShellApplication {
          name = "ccl";
          runtimeInputs = with pkgs; [
            curl
            jq
            fzf
            util-linux # column
            claude-code
            claude-code-router
          ];
          # Pin the claude binary rather than letting the router resolve it from PATH,
          # so ccl works the same from a bare shell as from an interactive login.
          text = ''
            export CLAUDE_PATH="${pkgs.claude-code}/bin/claude"

            ${builtins.readFile ./ccl.sh}
          '';
        };
      in
      {
        home.packages = [
          ccl
          # ccl execs `ccr code`, which in turn launches claude. Both must be on PATH
          # for the user too, so `ccr`/`claude` remain usable on their own.
          pkgs.claude-code
          pkgs.claude-code-router
        ];
      };
  };
}
```

- [ ] **Step 3: Enable it from the AI suite**

In `modules/suites/ai.nix`, add `apps.ccl.enable = true;` inside `config = lib.mkIf cfg.enable { ... }`, above the existing `home.extraOptions`, and update the option description. The result:

```nix
  options.suites.ai.enable = lib.mkEnableOption "local AI apps (LM Studio, ccl)";

  config = lib.mkIf cfg.enable {
    # ccl launches Claude Code against a model LM Studio is serving; it is useless
    # without LM Studio, so it ships with this suite rather than with development.
    apps.ccl.enable = true;

    home.extraOptions =
```

- [ ] **Step 4: Verify the build and shellcheck pass**

Run: `nix build --no-link .#nixosConfigurations.gamingpc.config.system.build.toplevel 2>&1 | tail -20`
Expected: builds successfully. A shellcheck violation in `ccl.sh` fails here with `In ccl.sh line N:` — fix and rerun until clean.

- [ ] **Step 5: Verify `--list` against the fixture**

Create the fixture and start the server per the "Test Fixture" section, then run the script directly (no rebuild needed):

Run:
```bash
CCL_LMSTUDIO_URL=http://127.0.0.1:8199 \
  bash /home/otis/sitolamix/modules/apps/ccl.sh --list
```

(`ccl.sh` has no shebang by design, so invoke it via `bash <path>`. Running it
directly this way skips the rebuild cycle during development.)

Expected — exactly three rows, embeddings model absent, unloaded model showing `-` for tools and `8192 ctx` from `max_context_length`:
```
big-model-70b  65536 ctx  tools  ● loaded
small-ctx-7b   4096 ctx   tools  ● loaded
vision-27b     8192 ctx   -      ○ not-loaded
```

- [ ] **Step 6: Verify the LM Studio-down error path**

Run: `CCL_LMSTUDIO_URL=http://127.0.0.1:9 bash /home/otis/sitolamix/modules/apps/ccl.sh --list; echo "exit=$?"`
Expected: the "LM Studio is not answering" message on stderr and `exit=1`.

- [ ] **Step 7: Commit**

```bash
git add modules/apps/ccl.sh modules/apps/ccl.nix modules/suites/ai.nix
git commit -m "feat(ccl): discover and list LM Studio chat models

First slice of ccl: the Nix module, the script skeleton, and --list.
Embeddings models are filtered out since they cannot serve chat."
```

---

### Task 2: Config generation via `--print-config`

**Files:**
- Modify: `modules/apps/ccl.sh`

**Interfaces:**
- Consumes: `die`, `models_json`, `candidates`, `LMSTUDIO_URL`, `ROUTER_PORT` from Task 1.
- Produces:
  - `validate_model <json> <id>` → exits 1 with the list of valid ids if `<id>` is not a selectable model; otherwise returns 0.
  - `effective_ctx <json> <id>` → stdout: integer context length.
  - `gen_config <id> <ctx>` → stdout: the router config JSON.

- [ ] **Step 1: Add the three functions to `ccl.sh`, after `list_models`**

```bash
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
```

- [ ] **Step 2: Wire `--print-config` into `main`**

Replace the whole `main` function with:

```bash
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
```

- [ ] **Step 3: Verify config generation against the fixture**

With the fixture server running:

Run: `CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh --print-config big-model-70b`

Expected — note `longContextThreshold` is the **number** 39321 (65536 × 60 ÷ 100), not a string:
```json
{
  "HOST": "127.0.0.1",
  "PORT": 4141,
  "Providers": [
    {
      "name": "lmstudio",
      "api_base_url": "http://127.0.0.1:8199/v1/chat/completions",
      "api_key": "lm-studio",
      "models": [ "big-model-70b" ]
    }
  ],
  "Router": {
    "default": "lmstudio,big-model-70b",
    "background": "lmstudio,big-model-70b",
    "think": "lmstudio,big-model-70b",
    "longContext": "lmstudio,big-model-70b",
    "longContextThreshold": 39321
  }
}
```

- [ ] **Step 4: Verify the unloaded-model context fallback**

Run: `CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh --print-config vision-27b | jq .Router.longContextThreshold`
Expected: `4915` (8192 × 60 ÷ 100, using `max_context_length` since the model is not loaded).

- [ ] **Step 5: Verify rejection of an embeddings model and an unknown id**

Run: `CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh --print-config nomic-embed; echo "exit=$?"`
Expected: `no selectable model with id nomic-embed`, then the three valid ids indented, then `exit=1`.

Run: `CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh --print-config nope; echo "exit=$?"`
Expected: same shape of error, `exit=1`.

- [ ] **Step 6: Verify the build still passes**

Run: `nix build --no-link .#nixosConfigurations.gamingpc.config.system.build.toplevel 2>&1 | tail -20`
Expected: builds successfully, no shellcheck findings.

- [ ] **Step 7: Commit**

```bash
git add modules/apps/ccl.sh
git commit -m "feat(ccl): generate router config with --print-config

longContextThreshold is 60% of the model's effective context — the loaded
context for resident models, the ceiling otherwise."
```

---

### Task 3: Small-context guard

**Files:**
- Modify: `modules/apps/ccl.sh`

**Interfaces:**
- Consumes: `MIN_CONTEXT` from Task 1, `effective_ctx` from Task 2.
- Produces: `warn_small_context <ctx>` → prints a warning to stderr when `ctx < MIN_CONTEXT`; always returns 0.

- [ ] **Step 1: Add `warn_small_context` to `ccl.sh`, after `gen_config`**

```bash
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
```

- [ ] **Step 2: Call it from `main`, immediately after the `print-config` early exit**

```bash
  if [[ "$mode" == "print-config" ]]; then
    printf '%s\n' "$config"
    exit 0
  fi

  warn_small_context "$ctx"

  die "interactive launch is not implemented yet"
```

- [ ] **Step 3: Verify the warning fires for a small-context model**

Run: `CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh small-ctx-7b 2>&1 | head -6`
Expected: the WARNING block naming `4096` and `32768`, followed by `ccl: interactive launch is not implemented yet`.

- [ ] **Step 4: Verify it stays silent for a large-context model**

Run: `CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh big-model-70b 2>&1 | grep -c WARNING; true`
Expected: `0`.

- [ ] **Step 5: Verify `--print-config` produces no warning on stdout**

Run: `CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh --print-config small-ctx-7b 2>/dev/null | jq -e . >/dev/null && echo "clean json"`
Expected: `clean json` — the guard must not run before the `print-config` exit, keeping that path side-effect-free.

- [ ] **Step 6: Commit**

```bash
git add modules/apps/ccl.sh
git commit -m "feat(ccl): warn when the model context is too small for Claude Code"
```

---

### Task 4: Interactive picker and atomic config write

**Files:**
- Modify: `modules/apps/ccl.sh`

**Interfaces:**
- Consumes: `candidates`, `die`, `CONFIG`, `CONFIG_DIR` from Tasks 1–2.
- Produces:
  - `pick_model <json>` → stdout: selected model id; empty output and non-zero status when the user cancels.
  - `write_config <json-content>` → writes `$CONFIG` atomically; backs up a pre-existing foreign config to `$CONFIG.pre-ccl` once.

- [ ] **Step 1: Add both functions to `ccl.sh`, after `warn_small_context`**

```bash
# The id is column 1 so the selection can be parsed with awk regardless of how
# `column` padded the rest. fzf exits non-zero when the user presses Esc; the
# caller distinguishes that from a real failure by checking for empty output.
pick_model() {
  candidates "$1" \
    | column -t -s $'\t' -o '  ' \
    | fzf --height=40% --reverse --no-multi \
          --header='Select an LM Studio model for Claude Code' \
    | awk '{ print $1 }'
}

write_config() {
  local content="$1" tmp
  mkdir -p "$CONFIG_DIR"
  # Preserve a config we did not write, exactly once. After the first run the file
  # is ccl-owned and rewritten on every launch, so re-backing it up would be noise.
  if [[ -f "$CONFIG" && ! -f "${CONFIG}.pre-ccl" ]]; then
    cp "$CONFIG" "${CONFIG}.pre-ccl"
    printf 'ccl: backed up your existing router config to %s.pre-ccl\n' "$CONFIG" >&2
  fi
  tmp="$(mktemp "${CONFIG_DIR}/.config.json.XXXXXX")"
  printf '%s\n' "$content" > "$tmp"
  mv -f "$tmp" "$CONFIG"
}
```

- [ ] **Step 2: Wire the picker into `main`, replacing the `validate_model` line**

```bash
  # `pick_model` runs in a command substitution, so an `exit` inside it would only
  # end the subshell. Detect cancellation by the empty result instead.
  if [[ -z "$model" ]]; then
    model="$(pick_model "$json")" || true
    if [[ -z "$model" ]]; then
      exit 0
    fi
  fi

  validate_model "$json" "$model"
```

- [ ] **Step 3: Call `write_config` in `main`, replacing the `die` placeholder**

```bash
  warn_small_context "$ctx"
  write_config "$config"

  die "router lifecycle is not implemented yet"
```

- [ ] **Step 4: Verify the picker selects and cancels correctly**

Run: `CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh`
Expected: fzf lists the three models; selecting `big-model-70b` proceeds to `ccl: router lifecycle is not implemented yet`.

Run the same command again and press `Esc`.
Expected: exits silently with status 0 and writes nothing.

- [ ] **Step 5: Verify the config lands on disk correctly**

Run: `jq -e '.Router.default == "lmstudio,big-model-70b"' ~/.claude-code-router/config.json && echo ok`
Expected: `ok`.

- [ ] **Step 6: Verify the one-time backup of a foreign config**

```bash
rm -f ~/.claude-code-router/config.json.pre-ccl
printf '{"mine":true}\n' > ~/.claude-code-router/config.json
CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh big-model-70b 2>&1 | grep backed
jq -e '.mine == true' ~/.claude-code-router/config.json.pre-ccl && echo "backup ok"
CCL_LMSTUDIO_URL=http://127.0.0.1:8199 bash /home/otis/sitolamix/modules/apps/ccl.sh big-model-70b 2>&1 | grep -c backed; true
```
Expected: the backup message on the first run, `backup ok`, then `0` on the second run — the backup happens once and is never overwritten.

- [ ] **Step 7: Verify the build still passes**

Run: `nix build --no-link .#nixosConfigurations.gamingpc.config.system.build.toplevel 2>&1 | tail -20`
Expected: builds successfully, no shellcheck findings.

- [ ] **Step 8: Commit**

```bash
git add modules/apps/ccl.sh
git commit -m "feat(ccl): add fzf model picker and atomic router config write

A foreign router config is preserved once as config.json.pre-ccl; after that
the file is ccl-owned and rewritten on every launch."
```

---

### Task 5: Router lifecycle, launch, and documentation

**Files:**
- Modify: `modules/apps/ccl.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: `write_config`, `CONFIG`, `STATE_DIR`, `ROUTER_URL`, `CONFIG_DIR`, `die` from earlier tasks.
- Produces:
  - `router_healthy` → returns 0 when `${ROUTER_URL}/health` answers.
  - `ensure_router` → guarantees a healthy router serving the current config, or exits 1 with log output.
- Final deliverable: `ccl` launches a working Claude Code session.

- [ ] **Step 1: Add the lifecycle functions to `ccl.sh`, after `write_config`**

```bash
router_healthy() {
  curl -fsS --max-time 2 "${ROUTER_URL}/health" >/dev/null 2>&1
}

# The router reads its config once at startup, so a config change means a restart.
# Hashing lets us skip that restart on the common path of relaunching the same model.
ensure_router() {
  local hash_file="${STATE_DIR}/active-config.sha256" want have="" i
  want="$(sha256sum < "$CONFIG" | cut -d' ' -f1)"
  if [[ -f "$hash_file" ]]; then
    have="$(cat "$hash_file")"
  fi

  if [[ "$want" == "$have" ]] && router_healthy; then
    return 0
  fi

  ccr stop >/dev/null 2>&1 || true
  ccr start >/dev/null 2>&1 || true

  for i in $(seq 1 30); do
    if router_healthy; then
      mkdir -p "$STATE_DIR"
      printf '%s\n' "$want" > "$hash_file"
      return 0
    fi
    sleep 0.5
  done

  printf 'ccl: the router never became healthy at %s (waited 15s)\n' "$ROUTER_URL" >&2
  printf 'ccl: last 20 lines of the router log:\n' >&2
  tail -qn 20 "${CONFIG_DIR}"/*.log 2>/dev/null >&2 || printf '  (no log file found)\n' >&2
  exit 1
}
```

- [ ] **Step 2: Add `--` passthrough to the argument loop in `main`**

Insert this case immediately **before** the `-*)` case, so `--` is matched first:

```bash
      --) shift; claude_args=("$@"); break ;;
```

And declare the array at the top of `main`, alongside the other locals:

```bash
  local mode="launch" model=""
  local -a claude_args=()
```

- [ ] **Step 3: Replace the `die` placeholder at the end of `main` with the launch**

```bash
  warn_small_context "$ctx"
  write_config "$config"
  ensure_router

  printf 'ccl: %s via the router on %s\n' "$model" "$ROUTER_URL" >&2
  exec ccr code "${claude_args[@]}"
```

- [ ] **Step 4: Verify the build passes, then activate**

Run: `nix build --no-link .#nixosConfigurations.gamingpc.config.system.build.toplevel 2>&1 | tail -20`
Expected: builds successfully, no shellcheck findings.

Then rebuild the system so `ccl` lands on PATH. Use the repo's usual command (see `Justfile`), e.g. `just rebuild` or `sudo nixos-rebuild switch --flake .#gamingpc`.

- [ ] **Step 5: Verify the real end-to-end launch**

Stop the fixture server first: `pkill -f "http.server 8199"`

With LM Studio running and a model loaded at 32k+ context:

Run: `ccl`
Expected: the picker lists your real models; selecting one prints `ccl: <model> via the router on http://127.0.0.1:4141` and Claude Code starts. Ask it `what model are you?` and confirm it responds — the response content does not matter, only that a round trip completes.

- [ ] **Step 6: Verify the restart-on-change and skip-on-same behavior**

Run: `time ccl <model-a> -- --version` then `time ccl <model-a> -- --version` again.
Expected: the second run is visibly faster — the hash matched and the router was reused rather than restarted.

Run: `ccl <model-b> -- --version`
Expected: succeeds; the config changed so the router restarted.

- [ ] **Step 7: Verify the passthrough and the router-failure path**

Run: `ccl <model-a> -- --version`
Expected: `claude`'s version string, confirming args after `--` reach Claude Code.

Run: `CCL_ROUTER_PORT=4142 ccl <model-a>` while something occupies 4142, e.g. `python3 -m http.server 4142 &`
Expected: after ~15s, the "never became healthy" message plus log tail, exit 1. Clean up with `pkill -f "http.server 4142"`.

- [ ] **Step 8: Document it in `README.md`**

Add this section after the `## ☁️ Cloud mounts (rclone)` section, matching its
structure. **The outer fence below is four backticks so the inner three-backtick
blocks survive; write only the inner content into the README.**

````markdown
## 🤖 Local models (ccl)

`ccl` runs Claude Code against a model served by LM Studio instead of Anthropic's
API. LM Studio speaks the OpenAI API and Claude Code speaks Anthropic's, so
[claude-code-router](https://github.com/musistudio/claude-code-router) sits between
them and translates. `ccl` picks the model, configures the router, starts it, and
hands off.

Enabled by `suites.ai.enable`.

### Everyday use

```
ccl                            pick a model interactively, then launch
ccl <model-id>                 launch with a specific model
ccl --list                     list selectable models and exit
ccl --print-config <model-id>  print the router config without writing it
ccl <model-id> -- --version    pass everything after -- to claude
```

Start LM Studio and load a model first — `ccl` only lists what LM Studio reports.

### Options

| Variable | Default | Meaning |
|---|---|---|
| `CCL_LMSTUDIO_URL` | `http://127.0.0.1:1234` | LM Studio base URL |
| `CCL_ROUTER_PORT` | `4141` | Port the router listens on |

`ccl` owns `~/.claude-code-router/config.json` and rewrites it on every launch. A
config it did not write is preserved once as `config.json.pre-ccl`.

### Troubleshooting

**"LM Studio is not answering"** — LM Studio's local server is off. Developer tab →
Status: Running.

**Context warning at launch** — the model was loaded with too small a context window.
Claude Code's system prompt and tool definitions alone exceed a few thousand tokens.
Raise "Context Length" in the model's settings in LM Studio and reload it.

**"the router never became healthy"** — something else holds port 4141, or the router
rejected the config. The message includes the tail of the router's log.

**Malformed tool calls, or the session derails** — expected with small quantised
models. Claude Code leans hard on well-formed tool calls; a 3-bit quant will not
always produce them. This is the model, not `ccl`.
````

- [ ] **Step 9: Commit**

```bash
git add modules/apps/ccl.sh README.md
git commit -m "feat(ccl): manage the router lifecycle and launch Claude Code

Hashing the generated config lets a relaunch of the same model reuse a running
router instead of restarting it. Documents the command in the README."
```

---

## Self-Review Notes

Checked against the spec:

- Module location, option name, and suite wiring — Task 1.
- `/api/v0` over `/v1/models` (needs `state`, `capabilities`, context lengths) — Task 1.
- Embeddings filter, `●`/`○` marker, tools flag, context column — Task 1.
- Positional model id skipping fzf — Task 2 parses it, Task 4 makes the picker conditional on it.
- Effective-context rule and numeric `longContextThreshold` at 60% — Task 2.
- 32768 warn-don't-block guard — Task 3.
- Atomic write, one-time `.pre-ccl` backup, not Nix-managed — Task 4.
- Hash comparison, `ccr stop`/`start`, 15s health poll, log tail on failure — Task 5.
- `CLAUDE_PATH` pinned to the Nix binary — Task 1 (module), used at exec in Task 5.
- `--` passthrough — Task 5.
- All six error-table rows — Task 1 (LM Studio down, no candidates), Task 2 (unknown id), Task 3 (small context), Task 4 (fzf cancel), Task 5 (router unhealthy).
- `--list` / `--print-config` as the test surface, no harness — Tasks 1–3.
- Known limitations documented — Task 5, README.

Two additions beyond the spec, both required to make its stated test surface actually testable: `CCL_LMSTUDIO_URL` and `CCL_ROUTER_PORT`. They double as legitimate configuration for a non-default LM Studio host or a busy port.
