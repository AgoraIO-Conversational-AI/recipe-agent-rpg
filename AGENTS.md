# Agent Development Guide

For coding agents working in `recipe-agent-rpg`. This repository is the **RPG
gaming** recipe in the Agora Conversational AI recipes family. A voice RPG where
a managed keyless OpenAI **Dungeon Master** narrates and calls **MCP game tools**;
the `mcp/` FastMCP server owns dice, combat, and inventory in **SQLite** with 6
self-contained tools; `MCP_ENDPOINT` must be public via ngrok.

## System shape

- **`server/`** — Python FastAPI agent backend (:8000). Owns Agora token
  generation and the Dungeon Master agent session lifecycle. Uses the managed
  `OpenAI` vendor with `mcp_servers` pointing at the public `mcp/` server and
  `enable_tools: true`. SDK: `agora-agents>=2.0.0` (`import agora_agent`).
- **`mcp/`** — Python FastMCP server (:8001). Streamable-HTTP MCP server that
  Agora cloud calls when the DM LLM emits a tool call. No `agora-agents`
  dependency. All 6 game tools live here; game state is in SQLite.
- **`web/`** — Next.js frontend (:3000), standard Agora quickstart with RPG
  branding. No character-sheet UI — game state is voice-only via `get_character`.
- Auth: Token007 from `AGORA_APP_ID` + `AGORA_APP_CERTIFICATE`. OpenAI is
  Agora-managed (keyless). `OPENAI_API_KEY` is optional.

## Routing / ownership

- UI and RTC/RTM lifecycle live in `web/`.
- Browser-facing `/api/*` paths are Next rewrites (`web/next.config.ts`) to the
  agent backend; do not add `web/app/api/**/route.ts` for agent/token logic.
- Token generation and agent lifecycle live in `server/src/`.
- All 6 MCP game tools live in `mcp/src/mcp_server.py`; pure game engine in
  `mcp/src/game.py` (no MCP import, fully unit-testable).

## The 6 tools

| Tool | Purpose |
| --- | --- |
| `create_character(char_class)` | Create/reset hero (warrior/mage/rogue/cleric) |
| `get_character()` | Read stats, HP, gold, inventory, current mode |
| `start_encounter()` | Spawn a random enemy, switch mode → combat |
| `attack()` | Resolve one attack round (dice + counterattack) |
| `cast_spell(name)` | Resolve a spell round (bonus die + counterattack) |
| `flee()` | Exit combat, clear enemy, switch mode → narration |

Each tool is **self-contained** — dice are rolled inside `game.py`, not by the
LLM. One player utterance maps to at most one tool call.

## Supported modes

- **Local:** `bun run dev` starts `mcp` (:8001), `server` (:8000), and `web`
  (:3000). The web app calls `/api/*`; Next rewrites to
  `AGENT_BACKEND_URL=http://localhost:8000`. The MCP server must be exposed
  publicly (ngrok) so Agora cloud can reach it.
- **Deploy:** deploy `web` (Next) + `server` (reachable FastAPI) + `mcp`
  (publicly reachable FastMCP). Set `AGENT_BACKEND_URL` in the web deployment.

## Key env vars

| Variable | Notes |
| --- | --- |
| `MCP_ENDPOINT` | Required, public ngrok URL ending in `/mcp` |
| `OPENAI_MODEL` | Default `gpt-4o-mini` |
| `RPG_DB_PATH` | Default `rpg.db` (relative to `mcp/`) |
| `RPG_SEED` | Optional integer — deterministic dice for tests |
| `OPENAI_API_KEY` | Optional — Agora manages it (keyless) |

## Patterns

- Keep the web client calling `/api/*`; hide backend placement behind Next rewrites.
- Keep token generation and the App Certificate in `server/`.
- Keep the `mcp/` server free of `agora-agents` — it is a standalone MCP service.
- `MCP_ENDPOINT` is required and must be public; there is no localhost default.
- `OPENAI_API_KEY` is optional — Agora manages it (keyless).
- Tools are self-contained — do not add tool-call chaining (the LLM resolves
  one utterance with at most one tool call).

## Anti-patterns

- Do not reintroduce Next Route Handlers for agent/token logic.
- Do not add `agora-agents` to `mcp/`.
- Do not default `MCP_ENDPOINT` to localhost.
- Do not put `PORT` in `server/.env.example` (it would clobber the random port
  that `verify:local:fastapi` injects via `load_dotenv(override=True)`).
- Do not change `mcp/src/game.py`, `mcp/src/mcp_server.py`, or
  `server/src/agent.py` without reading the full file first.

## Commands

```bash
bun run setup
bun run dev
bun run doctor
bun run doctor:local
bun run verify         # web-only, no creds
bun run verify:local   # full local gate
```

Narrower checks: `bun run verify:backend`, `bun run verify:web:proxy`.

## Done criteria

1. Run the narrowest relevant verification command.
2. Web-affecting changes: `bun run verify:web` passes.
3. Backend-affecting changes: `bun run verify:local` (or the narrower
   `verify:backend`) passes.
4. If you change required env vars or setup steps, update the root README, the
   relevant module README, and `server/.env.example` / `mcp/.env.example` together.

## Git conventions

- Conventional Commits: `type: description` or `type(scope): description`
  (`feat`, `fix`, `chore`, `test`, `docs`). Lowercase after the prefix, present
  tense.
- No AI tool names in commit messages or PR descriptions. No `Co-Authored-By`
  trailers. No `--no-verify`. No git config changes.
- Branch names: `type/short-description` (e.g. `feat/add-spell-tool`).
