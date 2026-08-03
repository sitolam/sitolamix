# `ccl` — LM Studio launcher for Claude Code

**Date:** 2026-08-03
**Status:** Design approved, ready for implementation plan

## Problem

Claude Code speaks the Anthropic Messages API. LM Studio, running locally on
`http://127.0.0.1:1234`, speaks only the OpenAI-compatible API. There is no way
to point Claude Code at a locally-loaded model without something translating
between the two.

Goal: a single command that lists the models LM Studio has, lets the user pick
one, and drops them into a normal Claude Code session backed by that model.

## Solution

A `ccl` command that discovers models, writes a
[claude-code-router](https://github.com/musistudio/claude-code-router) config,
ensures the router is running, and execs Claude Code against it.

claude-code-router does the API translation. It is packaged in nixpkgs
(`claude-code-router-2.0.0`), so we own only the thin launcher around it.

### Data flow

```
ccl ─→ LM Studio /api/v0/models      discover
    ─→ fzf                           choose
    ─→ ~/.claude-code-router/config.json
    ─→ ccr start :4141               ensure proxy
    └─→ exec ccr code ─→ claude
                          │ ANTHROPIC_BASE_URL=http://127.0.0.1:4141
                          ▼
                        ccr  /v1/messages ─→ /v1/chat/completions
                          ▼
                        LM Studio :1234
```

## Components

### `modules/apps/ccl.nix`

A new module following the existing `modules/apps/*.nix` convention:
`options.apps.ccl.enable = lib.mkEnableOption ...`, with the body under
`config = lib.mkIf cfg.enable { home.extraOptions = { pkgs, ... }: { ... }; }`.

The module is self-contained — it adds `claude-code` and `claude-code-router`
to `home.packages` alongside the `ccl` script itself, so enabling the option is
sufficient to get a working command. (`claude-code` also appears in
`modules/suites/development.nix`; the duplicate is harmless, both refer to the
same derivation.)

`modules/suites/ai.nix` sets `apps.ccl.enable = true`. `ccl` is useless without
LM Studio, so it belongs with the LM Studio suite rather than with the general
development tooling.

### The `ccl` script

A `pkgs.writeShellApplication` with
`runtimeInputs = [ curl jq fzf claude-code claude-code-router ]`.

#### 1. Discover

`GET http://127.0.0.1:1234/api/v0/models`. The `/api/v0` endpoint is used
rather than `/v1/models` because only the former reports `state`, `type`,
`capabilities`, `max_context_length`, and `loaded_context_length`.

#### 2. Filter and pick

A jq filter drops entries where `type == "embeddings"` — they cannot serve
chat completions — and formats the rest one per line with:

- a `●` / `○` marker for `state == "loaded"`
- the model id
- a `tools` flag when `capabilities` contains `tool_use`
- max context length

fzf presents the list. If the user passes a model id as the first positional
argument, fzf is skipped entirely, making the command usable from scripts.

#### 3. Context guard

The effective context is `loaded_context_length` for loaded models and
`max_context_length` otherwise. If it is below 32768, `ccl` prints a prominent
warning explaining that Claude Code's system prompt and tool definitions alone
exceed a small context, and points at LM Studio's per-model context setting.

It warns and continues rather than blocking. The user stays in control, and a
warning at launch is easier to connect to the cause than an opaque API error
surfacing mid-session.

#### 4. Configure

`ccl` generates `~/.claude-code-router/config.json`:

```json
{
  "HOST": "127.0.0.1",
  "PORT": 4141,
  "Providers": [
    {
      "name": "lmstudio",
      "api_base_url": "http://127.0.0.1:1234/v1/chat/completions",
      "api_key": "lm-studio",
      "models": ["<picked>"]
    }
  ],
  "Router": {
    "default": "lmstudio,<picked>",
    "background": "lmstudio,<picked>",
    "think": "lmstudio,<picked>",
    "longContext": "lmstudio,<picked>",
    "longContextThreshold": 19660
  }
}
```

`longContextThreshold` is a number, computed as 60% of the effective context
length and rounded down (the value above is the result for a 32768 context).

All four router roles point at the single picked model. Per-role assignment was
considered and rejected: it multiplies the steps at every launch to serve a case
(a small fast model handling background work) that only pays off with several
models resident at once, which this hardware cannot do.

The file is written atomically (temp file, then `mv`). It is **deliberately not
Nix-managed** — `ccl` rewrites it on every launch, so declaring it through
`home.file` or `xdg.configFile` would put the two in conflict. On first run, any
pre-existing config is copied to `config.json.pre-ccl`; after that, `ccl` owns
the file.

#### 5. Launch

The generated config's hash is compared against
`~/.cache/ccl/active-config.sha256`. If it differs, or if `:4141` is not
answering, `ccl` runs `ccr stop || true` then `ccr start` and polls for health
with a 15-second timeout. On timeout it dumps the tail of the router's log and
exits non-zero. On success it records the new hash.

Finally `exec ccr code "$@"`, with `CLAUDE_PATH` pinned to the Nix `claude`
binary so the router does not depend on PATH resolution. Remaining arguments
pass through to Claude Code.

The router runs on demand rather than as a systemd user unit. Nothing stays
resident when unused, and restarting it on config change is simpler than a
reload path.

## Interface

| Invocation | Behavior |
|---|---|
| `ccl` | Interactive picker, then launch |
| `ccl <model-id>` | Skip picker, launch with that model |
| `ccl --list` | Print candidate models, exit |
| `ccl --print-config <model-id>` | Print generated JSON, exit, touch nothing |
| `ccl [model-id] -- <args>` | Args after `--` pass through to `claude` |

The `--` separator is required for passthrough, so that `ccl` can tell its own
flags from Claude Code's. Anything before `--` is parsed by `ccl`; anything
after is forwarded untouched.

## Error handling

| Condition | Behavior |
|---|---|
| LM Studio not reachable on `:1234` | Message naming the address and that the local server must be enabled; exit 1 |
| No chat-capable models returned | Message explaining embeddings-only results; exit 1 |
| fzf cancelled (Esc) | Silent exit 0 |
| Model id argument not in the list | Error listing the valid ids; exit 1 |
| Router unhealthy after 15s | Tail of router log; exit 1 |
| Effective context < 32768 | Warn, continue |

## Testing

The two side-effect-free flags — `--list` and `--print-config` — are the test
surface. Both are deterministic given a fixed `/api/v0/models` response and can
be asserted against by hand or from a script.

No test harness is added. The repository has no test infrastructure today, and
this change does not justify introducing the first of it.

## Known limitations

**Tool-call reliability.** Claude Code depends heavily on well-formed tool
calls. `qwen3.6-35b-a3b` at IQ3_XXS will sometimes emit malformed ones. This is
a property of a 3-bit quantised model, not a defect in `ccl`.

**Speed.** This machine has an 8 GB RTX 2060 SUPER. A 35B MoE at 3-bit is
workable only because ~3B parameters are active per token, and it will still be
far slower than the hosted models.

**Upstream churn.** claude-code-router 2.0 is a recent rewrite. Its config
schema (`Providers[]` with `name` / `api_base_url` / `api_key` / `models` /
`transformer`, and `Router` with `default` / `background` / `think` /
`longContext` / `longContextThreshold` / `image` / `webSearch`) was read
directly out of the packaged 2.0.0 bundle. A future nixpkgs bump could change
it, and `ccl` would need updating to match.

## Rejected alternatives

**Writing our own translation proxy** (~500 lines handling Anthropic ↔ OpenAI
message shapes, tool schemas, and SSE stream translation). Full control and no
upstream dependency, but the streaming translation is exactly where the bugs
would live, and claude-code-router already solves it.

**LiteLLM.** Mature and packaged, exposes an Anthropic-format `/v1/messages`
endpoint. Rejected as a general-purpose gateway of which we would use a sliver,
at the cost of a full Python stack and slower startup.

**A standalone chat client** talking directly to LM Studio's OpenAI API. No
proxy needed, but it discards everything that makes Claude Code useful — the
agentic loop, tools, file editing, skills.
