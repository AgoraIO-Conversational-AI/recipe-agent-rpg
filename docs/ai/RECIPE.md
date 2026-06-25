---
recipe_version: 1.0.0
recipe_status: experimental
extension_points:
  - id: api.routes
    name: Browser-facing API routes
  - id: agent.dm-config
    name: Dungeon Master system prompt, model, greeting, and VAD config
  - id: agent.mcp-config
    name: MCP endpoint, mcp_servers list, and transport
  - id: game.tools
    name: Game tools in mcp_server.py and game engine in game.py
  - id: web.conversation-ui
    name: Conversation UI panels and controls
  - id: verification.contracts
    name: Contract, proxy, and local FastAPI smoke verification
invariants:
  - id: api.rewrite-boundary
    summary: Browser calls stay on /api/* and Next rewrites to FastAPI; no Route Handlers for agent/token logic.
  - id: secrets.server-only
    summary: Agora App Certificate stays in the Python backend. OPENAI_API_KEY is optional (Agora-managed).
  - id: mcp.single-process
    summary: The FastMCP game server is mounted in-process at /mcp via app.mount; it is not a separate service.
  - id: mcp.public-endpoint
    summary: MCP_ENDPOINT must be a public URL; Agora cloud (not the local server) calls it. No localhost default.
  - id: game.no-mcp-import
    summary: server/src/game.py must not import from mcp or mcp_server; it is a standalone unit-testable engine.
  - id: tools.self-contained
    summary: Each MCP tool resolves a whole action with at most one call; no tool-call chaining per utterance.
  - id: token.uid-concrete
    summary: Backend resolves missing, zero, or negative UIDs before issuing an RTC+RTM token.
stable_contracts:
  - id: env.required
    summary: AGORA_APP_ID, AGORA_APP_CERTIFICATE, and MCP_ENDPOINT are required; AGENT_BACKEND_URL is required by deployed web rewrites.
  - id: api.core-routes
    summary: GET /api/get_config, POST /api/startAgent, and POST /api/stopAgent remain the browser-facing contract.
  - id: response.envelope
    summary: Successful backend responses use { code, msg, data }.
  - id: mcp.transport-key
    summary: build_mcp_servers() returns transport="streamable_http" (underscore) for the Agora SDK mcp_servers field.
---

# Recipe Contract

This base recipe defines the reusable surface for a Python-backed Agora Conversational AI **RPG gaming** quickstart: a managed-keyless OpenAI Dungeon Master with 6 FastMCP game tools, backed by SQLite, behind a Next.js web client.

## Recipe Role

- Role: `base` recipe (self-contained, clone-and-run; no `Extends` pin).
- Target audience: developers building a voice RPG or multi-tool MCP agent with a Python FastAPI backend, in-process FastMCP server, and Next.js web client.
- Reuse model: clone, bind project, expose backend publicly (ngrok), run, then customize the game tools or DM prompt.

## Recipe Scope

- Python FastAPI token generation and managed agent lifecycle.
- A cascading STT (`DeepgramSTT`) → LLM (`OpenAI`, managed/keyless) → TTS (`MiniMaxTTS`) vendor pipeline.
- The managed `OpenAI` vendor configured with `mcp_servers` pointing at `MCP_ENDPOINT`.
- A FastMCP game server mounted in-process at `/mcp` exposing 6 self-contained tools.
- A pure SQLite game engine (`game.py`) with no MCP dependency, fully unit-testable.
- Next.js browser UI with RTC audio, RTM transcript/metrics, connection status.
- Rewrite-only `/api/*` browser facade hiding backend placement.
- Contract, proxy, and local FastAPI smoke verification that need no live Agora calls.

## Baseline Implementation Guidance

Use this repo's source and progressive disclosure docs as the starting point, then customize. Do not recreate the Agora ConvoAI integration from memory — vendor schemas, SDK builder fields, token behavior, and RTM details drift. Copy verified patterns from this repo.

## Extension Points

| ID | Surface | How to extend | Required follow-up |
| -- | ------- | ------------- | ------------------ |
| `api.routes` | `server/src/server.py`, `web/next.config.ts`, `web/src/services/api.ts` | Add FastAPI route, add rewrite, add browser fetch helper. | Extend `web/scripts/verify-api-contracts.ts`; add proxy/fastapi coverage if needed. |
| `agent.dm-config` | `server/src/agent.py` | Change `OPENAI_MODEL`, `turn_detection`, `greeting_message`, or the DM system prompt. | Run `verify:backend` + `pytest tests`; document new env in `server/.env.example` (never add `PORT`). |
| `agent.mcp-config` | `server/src/agent.py`, `server/src/mcp_config.py` | Change `MCP_ENDPOINT`, add more MCP servers, or change the transport. | Run `pytest tests/test_mcp_config.py`; ensure `MCP_ENDPOINT` stays public. |
| `game.tools` | `server/src/game.py`, `server/src/mcp_server.py` | Add/modify game logic in `game.py` (no MCP import); add/modify `@mcp.tool()` wrappers in `mcp_server.py`. | Add tests in `test_rpg.py`; update DM system prompt in `agent.py`. |
| `web.conversation-ui` | `web/src/components/*`, `web/src/lib/conversation.ts` | Customize pre-call, transcript, metrics, connection status, mic, or visualizer UI. | Preserve RTC/RTM lifecycle ownership and transcript UID normalization. |
| `verification.contracts` | `web/scripts/*.ts`, root `package.json` | Add checks for new browser/backend boundaries. | Keep checks runnable without live Agora credentials. |

## Invariants

- Browser code calls only `/api/get_config`, `/api/startAgent`, and `/api/stopAgent` for the default flow.
- Next.js owns `/api/*` through rewrites only; no `web/app/api/**/route.ts` for agent/token logic.
- FastAPI owns token generation, `AGORA_APP_CERTIFICATE`, and agent lifecycle.
- The FastMCP game server is mounted in-process at `/mcp`; it is not a separate service or process.
- `MCP_ENDPOINT` must be a public URL; Agora cloud calls it directly.
- `game.py` must not import from `mcp` or `mcp_server`.
- Each tool resolves a whole action in one call; no tool-call chaining per utterance.
- The backend issues one RTC+RTM-capable token for a concrete non-zero UID.

## Stable Contracts

| Contract | Stable shape |
| -------- | ------------ |
| Required backend env | `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`, `MCP_ENDPOINT` |
| Optional backend env | `OPENAI_MODEL`, `OPENAI_API_KEY`, `AGENT_GREETING`, `RPG_DB_PATH`, `RPG_SEED`, `PORT` (env only) |
| Required web deploy env | `AGENT_BACKEND_URL` |
| `GET /api/get_config` | Query `channel?`, `uid?`; returns `data.app_id`, `data.token`, `data.uid`, `data.channel_name`, `data.agent_uid`. |
| `POST /api/startAgent` | Body `{ channelName, rtcUid, userUid, parameters? }`; returns `data.agent_id`, `data.channel_name`, `data.status`. |
| `POST /api/stopAgent` | Body `{ agentId }`; returns `{ code: 0, msg: "success" }`. |
| Success envelope | `{ "code": 0, "msg": "success", "data": ... }` where the route has data. |
| MCP transport key | `"streamable_http"` (underscore) in `build_mcp_servers()` output. |
| Verification entry points | `bun run verify:web`, `bun run verify:backend`, `bun run verify:web:proxy`, `bun run verify:local`. |

## Internal / Subject to Change

- Visual layout, component composition, Tailwind classes, and assets under `web/src/components/`.
- Exact model name, VAD timing, voice, and greeting text, as long as they stay documented extension points.
- In-memory `Agent._sessions` details; the stable behavior is start by channel/user and stop by returned `agent_id`.
- Specific encounter table, loot table, and character class stat values in `game.py`.
- Verification internals under `web/scripts/`; the stable surface is the root script names and what they assert.
- `agora-agents` SDK minor-version behavior; this recipe lower-bounds `>=2.3.0` but does not freeze every field.

## Related Progressive Disclosure Docs

- `L1/01_setup.md` — setup, env, and commands.
- `L1/02_architecture.md` — request flow, single-process MCP, and topology.
- `L1/05_workflows.md` — common modification workflows.
- `L1/06_interfaces.md` — route, rewrite, env, and vendor contracts.
- `L1/L2/mcp_tool_config.md` — full vendor build and session options.
- `L1/L2/game_engine.md` — SQLite schema, combat flow, and dice seeding.
