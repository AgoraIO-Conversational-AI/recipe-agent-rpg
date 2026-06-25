# 05 · Workflows

> Step-by-step guides for the common changes in this recipe. Each ends with the narrowest verify command to run.

## Add or change a browser-facing route

1. Add the FastAPI handler in `server/src/server.py` (return the `{ code, msg, data }` envelope).
2. Add the `/api/<name>` → `/<name>` mapping in `web/next.config.ts` `rewrites()`.
3. Add a client helper in `web/src/services/api.ts`.
4. Extend `web/scripts/verify-api-contracts.ts` with the new path + envelope assertions.
5. Verify: `bun run verify:web:api` (and `bun run verify:web:proxy` to test through the rewrite map).

## Change the DM system prompt, greeting, or model

1. System prompt: edit the `system_messages` list in `Agent.start()` (`server/src/agent.py`).
2. Greeting: set `AGENT_GREETING` (env) or edit the default in `server/src/agent.py`.
3. Model: set `OPENAI_MODEL` (default `gpt-4o-mini`).
4. Verify: `bun run verify:backend` (compile check) + `cd server && pytest tests -v`.

## Add or modify a game tool

1. Add or modify the pure game logic in `server/src/game.py` (no MCP import allowed).
2. Add or update the corresponding `@mcp.tool()` function in `server/src/mcp_server.py`.
3. Add unit tests in `server/tests/test_rpg.py` (use a temp SQLite file + seeded `random.Random`).
4. Update the DM system prompt in `server/src/agent.py` if the tool changes the DM's guidance.
5. Verify: `cd server && pytest tests -v`.

## Adjust session parameters (codec, VAD)

1. Edit the `parameters` dict in `Agent.start()` (`audio_scenario`, `data_channel`, etc.). `output_audio_codec` is also accepted per-request via `parameters` on `POST /startAgent`.
2. To change turn detection: edit the `turn_detection` dict in `AgoraAgent(...)` in `Agent.start()`.
3. Verify: `bun run verify:backend`.

## Expose the backend publicly for MCP (ngrok)

1. `ngrok http 8000` — note the printed URL (e.g. `https://<tunnel>.ngrok-free.dev`).
2. Set `MCP_ENDPOINT=https://<tunnel>.ngrok-free.dev/mcp` in `server/.env.local`.
3. Restart `bun run dev` — the agent will pick up the new `MCP_ENDPOINT` on next `startAgent`.
4. `bun run doctor:local` to verify `MCP_ENDPOINT` is set and not pointing at localhost.

## Run / debug locally

```bash
bun run dev              # both processes
bun run doctor:local     # check creds + .env.local + MCP_ENDPOINT before a live call
```

## Verify before finishing

| Change touches…                        | Run                                                     |
| -------------------------------------- | ------------------------------------------------------- |
| Web only                               | `bun run verify:web`                                    |
| Backend logic / agent / game engine    | `bun run verify:backend` + `cd server && pytest tests -v` |
| Route/proxy boundary                   | `bun run verify:web:proxy`                              |
| Anything end-to-end (local)            | `bun run verify:local`                                  |

## Deploy

1. Deploy `web/` as a Next.js app.
2. Deploy `server/` (or any reachable FastAPI host); the published backend-only image is `ghcr.io/AgoraIO-Conversational-AI/recipe-agent-rpg` on `v*` tags. It runs one process on port 8000 with `/mcp` mounted.
3. Set `AGENT_BACKEND_URL` in the web deployment so rewrites reach the backend.
4. The deployed backend URL is itself the public `MCP_ENDPOINT` host — set `MCP_ENDPOINT=https://<deployed-backend>/mcp` in the backend deployment env.

## Related Deep Dives

- [mcp_tool_config](L2/mcp_tool_config.md) — vendor build, `mcp_servers` wiring, VAD config, and session options.
- [game_engine](L2/game_engine.md) — game.py internals, SQLite schema, deterministic dice, and combat flow.
