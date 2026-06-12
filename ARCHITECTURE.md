# Architecture — RPG Gaming Recipe

Three processes. The browser talks only to Next.js `/api/*`, which rewrites to
the agent backend. The agent backend owns Agora tokens and agent lifecycle. The
MCP game server is a separate service that **Agora cloud** calls directly to
execute tool calls; it must be publicly reachable.

**MCP multi-tool spike: GO (2026-06-12)** — a live Agora session confirmed `create_character` then `start_encounter` fired as distinct tools with SQLite state persisting across calls; the managed-LLM DM reliably called the tools.

## Request flow

```
Browser
  │  GET /api/get_config            → token + channel/UIDs
  │  POST /api/startAgent           → start Dungeon Master agent session
  ▼
Next.js  (rewrites /api/* → AGENT_BACKEND_URL)
  ▼
Agent backend (server/, :8000)
  │  builds session with OpenAI(mcp_servers=[{endpoint: MCP_ENDPOINT}])
  ▼
Agora ConvoAI Cloud
  │  user speech → Deepgram STT (managed)
  │  managed Dungeon Master LLM (keyless OpenAI) → emits tool call
  │  POST <MCP_ENDPOINT>   (streamable-http transport)
  ▼
MCP game server (mcp/, :8001, public via tunnel)
  │  executes tool (create_character / get_character / start_encounter /
  │                 attack / cast_spell / flee)
  │  → rolls dice, updates SQLite, returns plain-English result
  ▼
Agora ConvoAI Cloud → DM LLM incorporates result → narrates outcome
                     → MiniMax TTS (managed) → user hears speech
                     → RTM transcript / metrics → web UI
```

`POST /api/stopAgent { agentId }` ends the session.

## Why a separate MCP server

`server/` and `mcp/` are split because of an **exposure asymmetry**:

- `mcp/` must be reachable by **Agora cloud over the public internet** (hence
  the ngrok tunnel). It is the component you extend with your own tools, and it
  has no Agora dependency. It owns all game state in SQLite.
- `server/` only needs to be reachable by your web tier. It holds the Agora App
  Certificate and all token logic.

In production the two could be co-deployed, but they are kept separate here to
make that boundary — and the public-exposure requirement — explicit.

## Self-contained tools

Each of the 6 tools resolves a **whole action** in one call. Dice are rolled
inside `game.py`, not by the LLM. This design means:

- The DM never needs to chain multiple tool calls for one player utterance.
- Game outcomes are reproducible with `RPG_SEED`.
- The LLM's only job is narrative; it cannot invent HP values or loot.

## Single-player global state

SQLite state is global (no session id, matching Agora's single-user-per-session
model). The `character`, `enemy`, and `settings` tables each hold at most one
row. `get_character` is the voice-first stat sheet — the player asks the DM,
and the DM reads it aloud via the tool result; there is no character-sheet UI.

## Narrator ↔ combat flow

```
[narration mode]  player: "start a fight"
  → DM calls start_encounter() → enemy spawns, mode → "combat"
[combat mode]     player: "attack"
  → DM calls attack() → dice rolled, damage applied, enemy counterattacks
  → if enemy HP ≤ 0: mode → "narration", loot awarded
  → if player HP ≤ 0: hero deleted, mode → "narration", game over message
  → player: "run away"  → DM calls flee() → enemy cleared, mode → "narration"
```

## Distinct from recipe-agent-tool-calling

In `recipe-agent-tool-calling` the tools run **inside** the `llm/` endpoint:
the agent's custom LLM proxy intercepts tool calls and handles them locally. In
this recipe Agora cloud orchestrates the tools on the **separate `mcp/` server**
via the MCP protocol — the managed OpenAI vendor issues the tool call, Agora
invokes `MCP_ENDPOINT`, and the result flows back to the DM LLM.

## API (agent backend, port 8000)

| Endpoint | Method | Description |
| --- | --- | --- |
| `/get_config` | GET | Token + channel/UID config |
| `/startAgent` | POST | Start the Dungeon Master agent session |
| `/stopAgent` | POST | Stop the agent by `agent_id` |

The browser calls these as `/api/*`; Next rewrites them to `AGENT_BACKEND_URL`.

## Auth

- Browser → agent backend: none (local dev).
- Agent backend → Agora cloud: Token007, generated from `AGORA_APP_ID` +
  `AGORA_APP_CERTIFICATE`.
- Agora cloud → MCP game server: streamable-http (no auth on the dev server;
  add it for production use).
- OpenAI: Agora-managed (keyless) — `OPENAI_API_KEY` is optional.
