# 04 · Conventions

> Coding patterns shared across `server/` and `web/`. Follow these to keep local and deployed modes aligned and the game engine testable.

## Boundary ownership

- Browser code calls only `/api/*`. Backend placement is hidden behind Next rewrites (`web/next.config.ts`).
- **Never** add `web/app/api/**/route.ts` for agent/token logic — `verify-api-contracts.ts` fails the build if a `route.ts` appears under `app/api`.
- Token generation and the App Certificate stay in `server/`.
- Agora cloud calls `/mcp` directly via `MCP_ENDPOINT`; the browser never calls `/mcp`.

## Backend (Python / FastAPI)

- Async throughout: route handlers are `async def`; the agent uses `AsyncAgora` and `create_async_session`.
- Request bodies are Pydantic models (`StartAgentRequest`, `StopAgentRequest`). Field names are **camelCase** (`channelName`, `rtcUid`, `userUid`) to match the browser client.
- Error mapping is centralized: `_to_http_error()` maps `ValueError → 400`, `RuntimeError → 500`, else 500. `_log_route_error()` logs with safe context + traceback. Raise plain `ValueError`/`RuntimeError`; let the route convert.
- Logging via `logging.getLogger("uvicorn.error")`.
- Env read with `os.getenv`; `.env.local` then `.env` loaded with `override=True`.

## Response envelope

All backend JSON responses use:

```json
{ "code": 0, "msg": "success", "data": { } }
```

`data` is present only when the route returns a payload. The browser client treats `code !== 0` (or missing `data`) as an error.

## Game engine (`game.py`)

- `game.py` has **no MCP import** — it is a standalone SQLite-backed game engine. Keep it that way.
- Each function (`create_character`, `get_character`, `start_encounter`, `attack`, `cast_spell`, `flee`) opens and closes its own DB connection via `get_db()` (called by `mcp_server.py`'s `_run()` helper).
- Dice rolling uses a seedable `_RNG = random.Random(int(RPG_SEED))` — set `RPG_SEED` for deterministic tests.
- Game state is global (one row per table): `character`, `enemy`, `settings`. No session ID — matches Agora's single-user-per-session model.
- The DM never invents game outcomes — dice are rolled inside `game.py`, not by the LLM. Do not add LLM-generated numeric values to tool results.

## MCP tool convention

- Each of the 6 tools in `mcp_server.py` is **self-contained**: one call resolves a whole action.
- Tools return a plain-English result string for the DM to narrate; the LLM is responsible only for narration.
- `mcp_config.py` uses `"streamable_http"` (underscore) for the Agora SDK `transport` field. FastMCP uses `"streamable-http"` (hyphen) as its own transport name. These are different conventions — do not unify them.
- Tools are exposed via the FastMCP server mounted in-process at `/mcp` in `server.py`; they are not called locally by `agent.py`.

## Web (TypeScript / Next.js)

- Lint/format with Biome (`bun run lint`, `bun run lint:fix` in `web/`).
- RTC client creation must be StrictMode-safe (strict mode is on).
- Transcript speaker mapping uses real UIDs (`normalizeTranscript` maps `uid === '0'` to the local UID); do not heuristically guess speakers.
- API client lives in `src/services/api.ts`; UI never calls `fetch` to the backend directly.

## Testing approach

- Backend: `pytest` in `server/`, standalone — `conftest.py` fakes env, so no cloud or real creds are needed.
- Game engine tests (`test_rpg.py`) use temporary SQLite files and seeded `random.Random` for deterministic outcomes.
- Web: contract/proxy scripts under `web/scripts/` run without live Agora calls.
- Run the **narrowest** relevant verify command before finishing (see [05_workflows](05_workflows.md)).

## Doc upkeep

When you change request/response contracts, env vars, or workflow, update the web client, backend, contract checks, README, **and** the matching `docs/ai/L1/` file together, then bump `Last Reviewed` in [L0](../L0_repo_card.md).

## Related Deep Dives

- None.
