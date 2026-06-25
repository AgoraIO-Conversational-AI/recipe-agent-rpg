# 03 · Code Map

> Where things live. Two top-level modules: `web/` (Next.js client) and `server/` (FastAPI backend + MCP game server). Orchestration is in the root `package.json`.

## Root

| Path                  | Responsibility                                                                |
| --------------------- | ----------------------------------------------------------------------------- |
| `package.json`        | Bun workspace; `setup`, `dev`, `doctor*`, `verify*`, `clean` scripts.         |
| `README.md`           | Setup, run modes, env, architecture diagram, troubleshooting.                 |
| `ARCHITECTURE.md`     | System shape, single-process MCP design, combat flow, auth.                   |
| `AGENTS.md`           | Coding-agent handbook + How to Load / Git Conventions / Doc Commands.         |
| `Dockerfile`          | Backend-only image (`:8000`); runs one process serving both routes and `/mcp`.|
| `.github/workflows/`  | `ci.yml` (backend pytest matrix + web verify), `docker.yml`, `nightly.yml`.   |

## `server/` — FastAPI backend (:8000)

| Path                              | Responsibility                                                                     |
| --------------------------------- | ---------------------------------------------------------------------------------- |
| `src/server.py`                   | FastAPI app, CORS, route handlers, MCP lifespan, `app.mount("/", _mcp_asgi)`.     |
| `src/agent.py`                    | `Agent` class: `AsyncAgora` client, `start()`/`stop()`, `_sessions`, DM system prompt. |
| `src/mcp_server.py`               | FastMCP wrapper exposing 6 game tools; each calls `game.py` via `_run()`.          |
| `src/game.py`                     | Pure game engine: SQLite schema, `create_character`, `get_character`, `start_encounter`, `attack`, `cast_spell`, `flee`. No MCP import. |
| `src/mcp_config.py`               | `build_mcp_servers(endpoint)` — builds the `mcp_servers` list for the agent. No `agora_agent` import. |
| `scripts/run_fake_server.py`      | Boots `server.app` with a `FakeAgent` for the local FastAPI smoke test.            |
| `tests/test_rpg.py`               | Unit tests for `game.py` functions (create, combat, flee, seeded dice).            |
| `tests/test_agent_construction.py`| Builds the real `AgoraAgent`, fakes the SDK session, asserts start/stop shape.    |
| `tests/test_mcp_config.py`        | Asserts `build_mcp_servers` output shape and transport convention.                 |
| `tests/conftest.py`               | `fake_env` fixture; no cloud, no real creds.                                       |
| `.env.example`                    | Env template (do not add `PORT`).                                                  |
| `requirements*.txt`               | Runtime + dev (pytest) deps.                                                       |

## `server/src/server.py` routes

- `GET /get_config` — token + channel/UID config.
- `POST /startAgent` — start the Dungeon Master agent session with MCP tool calling.
- `POST /stopAgent` — stop by `agent_id`.
- `POST /mcp` (+ sub-paths) — FastMCP streamable-HTTP endpoint, called by Agora cloud; mounted via `app.mount("/", _mcp_asgi)`.

## `web/` — Next.js client (:3000)

| Path                                      | Responsibility                                                    |
| ----------------------------------------- | ----------------------------------------------------------------- |
| `next.config.ts`                          | `/api/*` rewrites to `AGENT_BACKEND_URL`; strict mode; Turbopack root. |
| `src/services/api.ts`                     | Browser API client: `getConfig`, `startAgent`, `stopAgent`.       |
| `src/lib/conversation.ts`                 | Transcript normalization, timestamp/UID mapping, visualizer state.|
| `src/lib/agora.ts`                        | Agora RTC/RTM helpers.                                            |
| `src/components/LandingPage.tsx`          | Conversation entry: config fetch, agent start, RTM login, teardown.|
| `src/components/ConversationComponent.tsx`| RTC join, mic publish, transcript/metrics/state listeners.        |
| `src/components/Quickstart*.tsx`          | Pre-call, transcript, metrics, layout panels.                     |
| `scripts/verify-api-contracts.ts`         | Asserts rewrites + client paths + response envelope (no network). |
| `scripts/verify-local-proxy.ts`           | Stub backend; proxies `/api/*` through the rewrite map.           |
| `scripts/verify-local-fastapi.ts`         | Spawns real FastAPI with `FakeAgent`; proxies routes end-to-end.  |
| `scripts/verify-local-llm.ts`             | Legacy script from tool-calling recipe lineage; not wired into `package.json` verify scripts. |
| `scripts/doctor.ts`                       | Web prerequisite check.                                           |

## Related Deep Dives

- None. For runtime flow see [02_architecture](02_architecture.md); for contracts see [06_interfaces](06_interfaces.md).
