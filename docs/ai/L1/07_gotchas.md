# 07 · Gotchas

> Non-obvious pitfalls specific to the RPG recipe. Read before changing the agent, env, verify scripts, or game engine.

## `MCP_ENDPOINT` must be public — no localhost default

`MCP_ENDPOINT` is validated at `Agent.__init__` — the server **fails to start** if it is unset. It must be a publicly reachable URL (e.g. `https://<tunnel>.ngrok-free.dev/mcp`) because Agora cloud (not the local server) calls it. There is no `localhost` fallback. Use `bun run doctor:local` to catch a missing or localhost-pointed `MCP_ENDPOINT` before a live session.

## `streamable_http` vs `streamable-http`

`mcp_config.py` uses `"streamable_http"` (underscore) for the Agora SDK `transport` field. The FastMCP server uses `"streamable-http"` (hyphen) as its own transport name. These are different conventions in different SDKs — do not unify them. `test_mcp_config.py` asserts the underscore form.

## Do not put `PORT` in `server/.env.example`

`verify:local:fastapi` injects a random `PORT` and loads env with `load_dotenv(override=True)`. A `PORT` line in `.env.example` (copied to `.env.local`) would clobber the injected port and break the smoke test.

## Keep `/api/*` ownership in rewrites

Adding `web/app/api/**/route.ts` for agent/token logic breaks the boundary — `verify-api-contracts.ts` explicitly fails if a `route.ts` exists under `app/api`. Token logic belongs in `server/`.

## Do not separate `mcp_server.py` and `game.py` into a standalone process

The recipe is designed for single-process operation: `mcp_server.py` is mounted in-process via `app.mount("/", _mcp_asgi)`. Splitting it into a separate port or service requires changes to `MCP_ENDPOINT`, the lifespan, and all verification scripts.

## Do not add tool-call chaining

The DM is designed to resolve **one player utterance with at most one tool call**. Tool results are plain-English strings; the LLM's job is narration only. Adding tool chaining (having one tool call trigger another) breaks the single-call-per-utterance contract and is not supported by the current prompt or game design.

## Do not add `OPENAI_API_KEY` as required

`OPENAI_API_KEY` is optional — Agora manages it. Marking it required would break the zero-key property and the CI smoke tests which run without it.

## camelCase request fields

`StartAgentRequest` uses `channelName`, `rtcUid`, `userUid` (camelCase) to match the browser client. Renaming one side without the other breaks the contract tests.

## UID normalization in transcripts

`normalizeTranscript` maps `uid === '0'` to the local UID. Token issuance also rejects zero/negative UIDs. Preserve both — speaker mapping and tokens depend on concrete UIDs.

## Local calls under a global proxy

Global proxies (Clash, etc.) can break `localhost`/RFC-1918 traffic. Configure the proxy to send `127.0.0.1`, `localhost`, and private ranges DIRECT, or use `socksio` (in `requirements.txt`) plus `all_proxy` to route the backend through SOCKS.

## `game.py` must stay free of MCP imports

`game.py` is a standalone game engine — unit-testable without the MCP stack. Any import from `mcp` or `mcp_server` in `game.py` breaks this isolation and makes tests depend on the full FastMCP install.

## Related Deep Dives

- [mcp_tool_config](L2/mcp_tool_config.md) — correct vendor/MCP wiring.
- [game_engine](L2/game_engine.md) — SQLite state, seeded dice, and combat flow.
