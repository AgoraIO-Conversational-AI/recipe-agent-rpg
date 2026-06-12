# Agent Development Guide

For coding agents working in `recipe-agent-mcp`. This repository is the **mcp**
recipe (`Recipe Role: mcp`) in the Agora Conversational AI recipes family.
Agora cloud orchestrates a tool on a separate MCP server: the managed keyless
OpenAI vendor emits a tool call, Agora invokes the `mcp/` FastMCP server (at
`MCP_ENDPOINT`, which must be public), returns the result, and the LLM speaks it.

## System shape

- **`server/`** — Python FastAPI agent backend (:8000). Owns Agora token
  generation and agent session lifecycle. Uses the managed `OpenAI` vendor with
  `mcp_servers` pointing at the public `mcp/` server. SDK: `agora-agents>=2.0.0`
  (`import agora_agent`).
- **`mcp/`** — Python FastMCP server (:8001). Streamable-HTTP MCP server that
  Agora cloud calls when the LLM emits a tool call. No `agora-agents` dependency.
  This is the component a developer extends with their own tools.
- **`web/`** — Next.js frontend (:3000), resynced from the base quickstart with
  MCP branding.
- Auth: Token007 from `AGORA_APP_ID` + `AGORA_APP_CERTIFICATE`. OpenAI is
  Agora-managed (keyless). `OPENAI_API_KEY` is optional.

## Routing / ownership

- UI and RTC/RTM lifecycle live in `web/`.
- Browser-facing `/api/*` paths are Next rewrites (`web/next.config.ts`) to the
  agent backend; do not add `web/app/api/**/route.ts` for agent/token logic.
- Token generation and agent lifecycle live in `server/src/`.
- MCP tool logic lives in `mcp/src/mcp_server.py`.

## Supported modes

- **Local:** `bun run dev` starts `mcp` (:8001), `server` (:8000), and `web`
  (:3000). The web app calls `/api/*`; Next rewrites to
  `AGENT_BACKEND_URL=http://localhost:8000`. The MCP server must be exposed
  publicly (ngrok) so Agora cloud can reach it.
- **Deploy:** deploy `web` (Next) + `server` (reachable FastAPI) + `mcp`
  (publicly reachable FastMCP). Set `AGENT_BACKEND_URL` in the web deployment.

## Patterns

- Keep the web client calling `/api/*`; hide backend placement behind Next rewrites.
- Keep token generation and the App Certificate in `server/`.
- Keep the `mcp/` server free of `agora-agents` — it is a standalone MCP service.
- `MCP_ENDPOINT` is required and must be public; there is no localhost default.
- `OPENAI_API_KEY` is optional — Agora manages it (keyless).

## Anti-patterns

- Do not reintroduce Next Route Handlers for agent/token logic.
- Do not add `agora-agents` to `mcp/`.
- Do not default `MCP_ENDPOINT` to localhost.
- Do not put `PORT` in `server/.env.example` (it would clobber the random port
  that `verify:local:fastapi` injects via `load_dotenv(override=True)`).

## Commands

```bash
bun run setup
bun run dev
bun run doctor
bun run doctor:local
bun run verify         # web-only, no creds
bun run verify:local   # full local gate
```

Narrower checks: `bun run verify:backend`, `bun run verify:web:proxy`.

## Done criteria

1. Run the narrowest relevant verification command.
2. Web-affecting changes: `bun run verify:web` passes.
3. Backend-affecting changes: `bun run verify:local` (or the narrower
   `verify:backend`) passes.
4. If you change required env vars or setup steps, update the root README, the
   relevant module README, and `server/.env.example` / `mcp/.env.example` together.

## Git conventions

- Conventional Commits: `type: description` or `type(scope): description`
  (`feat`, `fix`, `chore`, `test`, `docs`). Lowercase after the prefix, present
  tense.
- No AI tool names in commit messages or PR descriptions. No `Co-Authored-By`
  trailers. No `--no-verify`. No git config changes.
- Branch names: `type/short-description` (e.g. `feat/add-weather-tool`).
