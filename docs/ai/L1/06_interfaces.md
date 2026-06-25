# 06 · Interfaces

> Boundary contracts: backend routes, the `/api/*` rewrite map, env vars, the response envelope, and the managed OpenAI + MCP vendor config.

## Backend routes (port 8000)

The browser calls these as `/api/<name>`; Next rewrites to the backend `/<name>`. Agora cloud calls `/mcp` directly.

### `GET /get_config`

- Query (optional): `channel?: string`, `uid?: int` (≤ 0 or missing → backend generates one).
- Returns `data`: `{ app_id, token, uid (string), channel_name, agent_uid (string) }`.
- Token is a Token007 RTC+RTM token, expiry 3600s, for a concrete non-zero UID.

### `POST /startAgent`

- Body: `{ channelName: string, rtcUid: int, userUid: int, parameters?: object }`.
  - `parameters.output_audio_codec?: string` is the only honored parameter field.
- Returns `data`: `{ agent_id, channel_name, status: "started" }`.
- 400 if `channelName`/`rtcUid`/`userUid` invalid or `MCP_ENDPOINT` is unset (fails at construction).

### `POST /stopAgent`

- Body: `{ agentId: string }`.
- Returns `{ code: 0, msg: "success" }` (no `data`).

### `POST /mcp` (+ sub-paths)

- FastMCP streamable-HTTP endpoint. Called by Agora cloud, **not** by the browser.
- Agora cloud POSTs to `<MCP_ENDPOINT>` (the public URL); the process receives it at `/mcp`.
- No auth on this endpoint in the dev recipe — add auth before production use.

## Response envelope

```json
{ "code": 0, "msg": "success", "data": { } }
```

`data` omitted when the route has no payload. Non-zero `code` or missing `data` = error on the client side.

## Rewrite map (`web/next.config.ts`)

| Browser path        | Backend destination |
| ------------------- | ------------------- |
| `/api/get_config`   | `/get_config`       |
| `/api/startAgent`   | `/startAgent`       |
| `/api/stopAgent`    | `/stopAgent`        |

`rewrites()` returns `[]` when `AGENT_BACKEND_URL` is unset. The contract is asserted by `verify-api-contracts.ts` and exercised by `verify-local-proxy.ts`.

## Browser API client (`web/src/services/api.ts`)

- `getConfig({ channel?, uid? }) → GetConfigResponse`
- `startAgent(channelName, rtcUid, userUid) → agent_id`
- `stopAgent(agentId) → void`

## Environment variables

| Variable                | Scope              | Required     | Default        |
| ----------------------- | ------------------ | :----------: | -------------- |
| `AGORA_APP_ID`          | backend            |    ✅        | —              |
| `AGORA_APP_CERTIFICATE` | backend            |    ✅        | —              |
| `MCP_ENDPOINT`          | backend            |    ✅        | — (public URL ending in `/mcp`; cannot be localhost) |
| `OPENAI_MODEL`          | backend            |              | `gpt-4o-mini`  |
| `RPG_DB_PATH`           | backend            |              | `/tmp/rpg.db`  |
| `RPG_SEED`              | backend            |              | — (integer, deterministic dice) |
| `OPENAI_API_KEY`        | backend            |              | — (Agora-managed by default) |
| `AGENT_GREETING`        | backend            |              | built-in DM line |
| `AGENT_BACKEND_URL`     | web (deploy)       |  ✅\*        | `http://localhost:8000` (dev) |
| `PORT`                  | backend (env only) |              | `8000` — do **not** put in `.env.example` |

\* Required wherever the web app is deployed; rewrites are empty without it.

## Managed OpenAI vendor + MCP servers config (`agent.py`)

`Agent.start()` constructs the vendor pipeline:

```python
llm = OpenAI(
    api_key=self.openai_api_key,          # optional (None = Agora-managed keyless)
    model=self.openai_model,              # OPENAI_MODEL, default gpt-4o-mini
    system_messages=[{"role": "system", "content": "...DM system prompt..."}],
    mcp_servers=build_mcp_servers(self.mcp_endpoint),  # [{name, endpoint, transport}]
    greeting_message=self.greeting,
)
stt = DeepgramSTT(model="nova-3", language="en")
tts = MiniMaxTTS(model="speech_2_6_turbo", voice_id="English_captivating_female1")
```

`AgoraAgent` uses cascading `.with_stt(stt).with_llm(llm).with_tts(tts)`.

## MCP servers list (`mcp_config.py`)

`build_mcp_servers(endpoint)` returns:

```python
[{"name": "rpg", "endpoint": endpoint, "transport": "streamable_http"}]
```

Note: Agora SDK uses `"streamable_http"` (underscore); FastMCP uses `"streamable-http"` (hyphen). Do not unify.

## The 6 MCP tools

| Tool                     | Arg(s)        | When the DM calls it                        |
| ------------------------ | ------------- | ------------------------------------------- |
| `create_character`       | `char_class`  | Player picks/changes class (warrior/mage/rogue/cleric) |
| `get_character`          | —             | Player asks about stats, HP, gold, inventory |
| `start_encounter`        | —             | Player looks for a fight or story leads into danger |
| `attack`                 | —             | Player attacks the current enemy            |
| `cast_spell`             | `name`        | Player casts their class spell              |
| `flee`                   | —             | Player runs from combat                     |

## Related Deep Dives

- [mcp_tool_config](L2/mcp_tool_config.md) — full vendor build, `mcp_servers` wiring, and session parameters.
