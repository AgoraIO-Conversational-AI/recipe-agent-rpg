# 02 · Architecture

> Two co-located processes. The browser talks only to Next.js `/api/*`, which rewrites to the FastAPI agent backend. The backend owns Agora tokens, the Dungeon Master agent session, **and** the FastMCP game server — all in one process on port 8000.

## Topology

```
Browser (localhost:3000)
  │  fetch /api/*
  ▼
Next.js (web/)  ──rewrite──▶  Agent backend (server/, :8000)
                                 │  builds OpenAI vendor (managed, keyless) + mcp_servers=[MCP_ENDPOINT]
                                 │  also mounts FastMCP game server at /mcp (in-process)
                                 ▼
                              Agora ConvoAI Cloud
                                 │  user speech → Deepgram STT (managed)
                                 │  Dungeon Master LLM (managed OpenAI) → emits tool call
                                 │  POST <MCP_ENDPOINT>   (streamable-http)
                                 ▼
                              FastMCP game server (mounted at /mcp, same process as backend)
                                 │  public via ngrok tunnel on :8000
                                 │  resolves tool (dice rolled in game.py, SQLite updated)
                                 ▼
                              Agora ConvoAI Cloud → DM LLM narrates result
                                                 → MiniMax TTS (managed) → user hears speech
                                                 → RTM transcript / metrics → web UI
```

- **`web/`** — Next.js / React / TypeScript. Owns UI plus the RTC/RTM client lifecycle. Calls only `/api/*`.
- **`server/`** — Python FastAPI (:8000). Owns Agora token generation, agent session lifecycle, and the FastMCP game server mounted at `/mcp`. SDK: `agora-agents>=2.3.0` (`import agora_agent`).
- No `llm/` service — the managed `OpenAI` vendor handles STT/LLM/TTS via Agora ConvoAI cloud.

## Request lifecycle

1. Browser `GET /api/get_config` → Next rewrites to backend `/get_config`; backend mints a Token007 from `AGORA_APP_ID` + `AGORA_APP_CERTIFICATE` and returns channel + UIDs.
2. Browser joins the RTC channel, then `POST /api/startAgent`; backend builds the `OpenAI` vendor with `mcp_servers=[{endpoint: MCP_ENDPOINT}]` and starts an async agent session.
3. User speaks (e.g. "I want to be a warrior"). Agora runs Deepgram STT and sends the transcript to the managed Dungeon Master LLM.
4. The DM LLM emits a tool call (`create_character("warrior")`). Agora cloud POSTs to `MCP_ENDPOINT` (streamable-http). The FastMCP game server (mounted at `/mcp`) runs the tool via `game.py`, updates SQLite, and returns a plain-English result.
5. Agora feeds the tool result back to the DM LLM, which narrates it. MiniMax TTS plays the speech back. RTM delivers transcript + metrics to the web UI.
6. `POST /api/stopAgent { agentId }` ends the session.

## Single-process MCP design

The FastMCP game server is mounted in-process via `app.mount("/", _mcp_asgi)` in `server/src/server.py`. A shared lifespan (`_mcp_asgi.session_manager.run()`) manages the MCP session manager. This means:

- One port (8000) and one tunnel serve both the token endpoints and MCP tool calls.
- Agora cloud calls `<public-url>/mcp` — the same host the browser reaches for `/get_config` and `/startAgent`, just at the `/mcp` path.
- `server/src/game.py` has no MCP import and is fully unit-testable in isolation.

## Key abstractions

- **`Agent`** (`server/src/agent.py`) — async wrapper around `AgoraAgent`; owns the `AsyncAgora` client, env, and the in-memory `_sessions` map keyed by `agent_id`.
- **`game.py`** — pure game engine (SQLite, no MCP import). All dice rolling, combat resolution, and inventory logic live here. Seedable via `RPG_SEED`.
- **`mcp_server.py`** — FastMCP wrapper exposing 6 game tools; each tool calls `game.py` and returns a plain-English result for the DM to narrate.
- **`mcp_config.py`** — pure builder (`build_mcp_servers(endpoint)`) for the `mcp_servers` list; no `agora_agent` import, fully testable.
- **Rewrite proxy** (`web/next.config.ts`) — the only browser→backend boundary; no Next Route Handlers for agent/token logic.

## Tech decisions

- **Rewrites, not Route Handlers** — hides backend placement behind `/api/*` so the same client works locally and deployed (set `AGENT_BACKEND_URL`).
- **Managed keyless OpenAI** — Agora manages the OpenAI key; `OPENAI_API_KEY` is optional. This is distinct from `recipe-agent-realtime` (BYO-key MLLM).
- **In-process MCP** — reduces infrastructure to a single port and tunnel, at the cost of requiring a public URL for local dev.
- **Self-contained tools** — each of the 6 tools resolves a whole action (dice rolled in `game.py`); the DM never chains tool calls for one utterance.

## Related Deep Dives

- [mcp_tool_config](L2/mcp_tool_config.md) — vendor build, `mcp_servers` wiring, VAD config, and session options.
- [game_engine](L2/game_engine.md) — `game.py` internals, SQLite schema, combat flow, and `RPG_SEED`.
