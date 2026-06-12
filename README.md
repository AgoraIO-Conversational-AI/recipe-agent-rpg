# Agora Conversational AI — RPG Gaming Recipe (Python)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Python](https://img.shields.io/badge/python-%3E%3D3.10-blue)](https://www.python.org/)
[![Bun](https://img.shields.io/badge/bun-latest-black)](https://bun.sh/)

The **RPG gaming** recipe in the Agora Conversational AI recipes family. A voice
RPG where a managed-LLM **Dungeon Master** narrates the adventure and calls
**game tools** on a separate FastMCP server. The player speaks; the DM resolves
every mechanic — dice rolls, combat, loot, inventory — through 6 self-contained
MCP tools backed by SQLite. STT (Deepgram) and TTS (MiniMax) are Agora-managed.

This recipe is **zero-key**: OpenAI is Agora-managed (no `OPENAI_API_KEY`
needed, though you may supply your own). The `mcp/` server is a self-contained
game engine with no external credentials. The full pipeline runs locally with
only Agora credentials and a public tunnel.

**Distinct from `recipe-agent-tool-calling`**: in that recipe tools run inside
the `llm/` endpoint. Here Agora cloud orchestrates them on a **separate MCP
server** — the `mcp/` service is a standalone FastMCP HTTP server, and Agora
cloud calls it directly at `MCP_ENDPOINT`.

## Prerequisites

- [Python 3.10+](https://www.python.org/)
- [Bun](https://bun.sh/)
- [Agora CLI](https://github.com/AgoraIO/cli) — generates App ID + Certificate
- [ngrok](https://ngrok.com/) — the MCP server must be publicly reachable so
  Agora cloud can call it

## Run It

```bash
# 1. Install Python venvs + web deps
bun run setup

# 2. Add Agora credentials to server/.env.local
agora login
agora project use <your-project>
agora project env write server/.env.local

# 3. Expose the MCP server publicly — Agora cloud calls it directly
ngrok http 8001

# 4. Set MCP_ENDPOINT in server/.env.local (use whatever domain ngrok prints)
#    MCP_ENDPOINT=https://<your-tunnel>.ngrok-free.dev/mcp

# 5. Run all three services
bun run dev
```

Open [http://localhost:3000](http://localhost:3000) → **Start Conversation** →
say "I want to be a warrior" to create your hero, then explore and fight.

### Working from a clone

If you cloned this repo (rather than scaffolding via the Agora CLI), the steps
above are complete as written: `bun run setup` creates both Python venvs and
installs web dependencies, then `bun run dev` brings up all three services. You
still need Agora credentials in `server/.env.local` and a public `MCP_ENDPOINT`
tunnel before a conversation can connect.

Services:

- Frontend — http://localhost:3000
- Backend — http://localhost:8000
- MCP game server — http://localhost:8001
- API docs — http://localhost:8000/docs

## Deploy

Deploy `web` (Next.js) and `server` (a reachable FastAPI backend). Set
`AGENT_BACKEND_URL` in the web deployment so the Next rewrites reach the backend.

The `mcp/` server must be publicly reachable so Agora cloud can call it; deploy
it separately (or co-hosted) and update `MCP_ENDPOINT` to match.

A multi-process Docker image is published to
`ghcr.io/AgoraIO-Conversational-AI/recipe-agent-rpg` on `v*` tags. It bundles
the agent backend (:8000) **and** the MCP server (:8001) in one image. To host
the single-image demo, expose :8001 publicly and point `MCP_ENDPOINT` at it. A
local `docker run` still needs a tunnel, because Agora cloud cannot reach
`localhost`. The bundled mock game server is a development stand-in you replace
with your own tools.

## Environment variables

Backend env file: [`server/.env.example`](server/.env.example).

| Variable | Required | Default | Notes |
| --- | :---: | :---: | --- |
| `AGORA_APP_ID` | Yes | — | Agora Console → Project → App ID |
| `AGORA_APP_CERTIFICATE` | Yes | — | Agora Console → Project → App Certificate |
| `MCP_ENDPOINT` | Yes | — | **Public** URL of the `mcp/` server (e.g. `https://<tunnel>/mcp`). Agora cloud calls it; cannot be `localhost`. |
| `OPENAI_MODEL` | | `gpt-4o-mini` | Model name for the managed Dungeon Master LLM |
| `RPG_DB_PATH` | | `rpg.db` | Path to the SQLite database for game state |
| `RPG_SEED` | | — | Optional integer seed for deterministic dice (useful for testing) |
| `OPENAI_API_KEY` | | — | Optional — Agora manages the OpenAI key (keyless by default) |
| `AGENT_GREETING` | | built-in | Optional override for the DM's opening line |
| `PORT` | | `8000` | Agent backend port |
| `MCP_PORT` (mcp/.env.local) | | `8001` | Port for the MCP game server |
| `AGENT_BACKEND_URL` (web deploy) | Yes (deploy) | — | Required when deploying `web` |

## Commands

```bash
bun run setup            # install web deps + create server/ and mcp/ venvs
bun run dev              # run mcp (:8001) + backend (:8000) + web (:3000)

bun run doctor           # prerequisite check (no creds needed)
bun run doctor:local     # + .env.local + credentials + MCP_ENDPOINT checks

bun run verify           # web-only gate (no Agora creds needed)
bun run verify:local     # full local gate: backend compile + web build
bun run clean            # remove venvs and build artifacts
```

Tests run standalone: `pytest` in `server/` and `mcp/`, plus `bun run verify`
in `web/`. CI runs them on Linux/macOS/Windows × Python 3.10 & 3.13.

## Architecture

```
Browser (localhost:3000)
  │  fetch /api/*
  ▼
Next.js  ──rewrite──▶  Agent backend  (server/, localhost:8000)
                          │  starts agent session (Dungeon Master LLM + mcp_servers)
                          ▼
                       Agora ConvoAI Cloud
                          │  user speech → Deepgram STT (managed)
                          │  Dungeon Master LLM (managed OpenAI, keyless) → emits tool call
                          │  POST <MCP_ENDPOINT>   (streamable-http)
                          ▼
                       MCP game server  (mcp/, localhost:8001)
                          ▲  public via ngrok tunnel
                          │  resolves dice/combat/inventory → returns result
                          ▼
                       Agora ConvoAI Cloud → DM narrates outcome
                                          → MiniMax TTS (managed) → user hears speech
                                          → RTM transcript / metrics → web UI
```

The browser only ever calls Next `/api/*`, which rewrites to the agent backend.
The agent backend owns Agora tokens and agent lifecycle. The **MCP game server**
is separate because Agora cloud — not the browser — calls it, so it must be
publicly reachable. See [ARCHITECTURE.md](./ARCHITECTURE.md).

## What You Get

- A **voice RPG** where a managed-LLM Dungeon Master narrates the adventure and
  calls game tools — no UI to click, no state to manage client-side.
- A managed-LLM DM that narrates and calls **6 self-contained MCP tools**: dice
  rolling, character creation, combat rounds, spells, fleeing, and inventory reads.
- **SQLite** backs dice, combat, and inventory in `mcp/` — no external game server
  or database required.
- **Zero-key**: OpenAI is Agora-managed and the `mcp/` game engine needs no
  external credentials. The full pipeline runs locally with only Agora credentials
  and a public tunnel.

| Tool | When the DM calls it |
| --- | --- |
| `create_character(char_class)` | Player picks or changes their class (warrior/mage/rogue/cleric) |
| `get_character()` | Player asks about their stats, HP, gold, or inventory |
| `start_encounter()` | Player looks for a fight or the story leads into danger |
| `attack()` | Player attacks the current enemy |
| `cast_spell(name)` | Player casts their class spell |
| `flee()` | Player runs from combat |

Each tool opens its own SQLite connection, resolves the full action (including
dice rolls and counterattacks), and returns a plain-English result for the DM to
narrate. No chaining — one player utterance maps to at most one tool call.

## How It Works

1. The browser calls `/api/get_config`; the backend mints an Agora token.
2. The browser joins the RTC channel, then calls `/api/startAgent`; the backend
   starts an agent session using the managed `OpenAI` vendor with `mcp_servers`
   pointing at the public `MCP_ENDPOINT` and `enable_tools: true`.
3. The user speaks (e.g. "I want to be a warrior"). Agora runs STT (Deepgram)
   and sends the transcript to the managed Dungeon Master LLM.
4. The DM decides to call `create_character("warrior")`. Agora cloud issues a
   streamable-HTTP request to `MCP_ENDPOINT`. The `mcp/` FastMCP server runs
   the tool (creates the SQLite row, rolls no dice here), and returns a narrative
   result string.
5. Agora feeds the tool result back to the DM LLM, which narrates it (e.g.
   "You are a warrior with 30 HP…"). Agora runs TTS (MiniMax) and plays it back.
6. Later tools (`start_encounter`, `attack`, `cast_spell`, `flee`) resolve combat
   in the same way — each tool is **self-contained** (dice rolled inside `game.py`,
   no tool-call chaining).
7. `/api/stopAgent` ends the session.

## Repo Map

- `web/` — Next.js frontend (:3000); RTC/RTM lifecycle and UI.
- `server/` — FastAPI agent backend (:8000); Agora tokens + Dungeon Master agent lifecycle.
- `mcp/` — FastMCP game server (:8001); dice, combat, and inventory in SQLite.
- `ARCHITECTURE.md` — system shape and component boundaries.
- `AGENTS.md` — guide for coding agents working in this repo.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| DM greets but never calls a tool | `MCP_ENDPOINT` is not public or the `/mcp` path is wrong. Use your ngrok URL. |
| `doctor:local` warns about localhost | Replace the local URL with your public tunnel URL. |
| Local calls fail under a global proxy | Configure the proxy to send `127.0.0.1` and `localhost` DIRECT. |
| Tests fail with wrong dice outcomes | Set `RPG_SEED` to a fixed integer; the tests already do this automatically. |

## More Docs

- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [AGENTS.md](./AGENTS.md)

## License

Released under the [MIT License](./LICENSE).
