# 08 · Security

> Trust boundaries, secret handling, and auth for the RPG recipe.

## Trust boundaries

| Hop                                | Auth                                                                         |
| ---------------------------------- | ---------------------------------------------------------------------------- |
| Browser → agent backend            | None in local dev (the `/api/*` rewrite is same-origin).                     |
| Agent backend → Agora cloud        | Token007, generated from `AGORA_APP_ID` + `AGORA_APP_CERTIFICATE`.           |
| Agora cloud → FastMCP game server  | None (unauthenticated streamable-HTTP in dev; add auth before production).   |
| OpenAI                             | Agora-managed (keyless) by default; `OPENAI_API_KEY` optional BYO.          |

## Secret handling

- **Server-only secrets:** `AGORA_APP_CERTIFICATE` lives only in `server/.env.local` and never reaches the browser. The browser receives a short-lived token, never the certificate.
- `OPENAI_API_KEY` is optional and server-side only when supplied.
- `server/.env.local` is gitignored; `server/.env.example` ships placeholders only.
- Tokens (`generate_convo_ai_token`) expire after 3600s and are minted per `get_config` call for a concrete non-zero UID.

## CORS

The backend sets `CORSMiddleware` with `allow_origins=["*"]` — open by design for a local/dev recipe. **Lock this down to known origins before any production deployment.**

## `/mcp` endpoint

The FastMCP game server at `/mcp` is unauthenticated in this recipe. In production deployments you should add shared-secret or token verification so that arbitrary callers cannot trigger game state changes.

## Validation

- `Agent.__init__` raises `ValueError` if `MCP_ENDPOINT` is unset or if `AGORA_APP_ID`/`AGORA_APP_CERTIFICATE` are missing.
- `Agent.start()` rejects empty `channel_name` and non-positive `agent_uid`/`user_uid` before issuing tokens or starting a session.
- Route errors are sanitized: `_log_route_error` logs only non-`None` context; SDK exceptions map to 400/500 without leaking internals to the client beyond the message.

## Deployment notes

- Set `AGENT_BACKEND_URL` only to a backend you control; the rewrite forwards browser requests there verbatim.
- The published Docker image is **backend-only** (`:8000`); it does not bundle secrets.
- The backend must be publicly reachable so Agora cloud can call `/mcp`. In deployment, the same HTTPS URL is both `AGENT_BACKEND_URL` (for the browser rewrite) and the host for `MCP_ENDPOINT`.

## Related Deep Dives

- None.
