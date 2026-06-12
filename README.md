# Agora Conversational AI — MCP Recipe (Python)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Python](https://img.shields.io/badge/python-%3E%3D3.10-blue)](https://www.python.org/)
[![Bun](https://img.shields.io/badge/bun-latest-black)](https://bun.sh/)

The **mcp** recipe in the Agora Conversational AI recipes family. Agora cloud
orchestrates a tool on a separate MCP server: the managed keyless OpenAI vendor
emits a tool call, Agora invokes the `mcp/` FastMCP server (which must be
publicly reachable), returns the result, and the LLM speaks it. STT (Deepgram)
and TTS (MiniMax) stay Agora-managed.

This recipe is **zero-key**: OpenAI is Agora-managed (no `OPENAI_API_KEY`
needed), and the `mcp/` tool is a mock (`get_time`) that needs no external
credentials. Replace it with your own tools.

**Distinct from `recipe-agent-tool-calling`**: in that recipe the tools run
inside the `llm/` endpoint. Here Agora orchestrates them on a separate MCP
server — the `mcp/` service is a standalone FastMCP HTTP server, and Agora
cloud calls it directly at `MCP_ENDPOINT`.

## Prerequisites

- [Python 3.10+](https://www.python.org/)
- [Bun](https://bun.sh/)
- [Agora CLI](https://github.com/AgoraIO/cli) — makes generating an App ID + App Certificate easy
- [ngrok](https://ngrok.com/) — the MCP server must be publicly reachable so Agora cloud can call it

## Run It

```bash
# 1. Install Python venvs + web deps
bun run setup

# 2. Add Agora credentials to server/.env.local
agora login
agora project use <your-project>
agora project env write server/.env.local

# 3. Expose the MCP server publicly — Agora cloud calls it directly
ngrok http 8001

# 4. Set MCP_ENDPOINT in server/.env.local (use whatever domain ngrok prints)
#    MCP_ENDPOINT=https://<your-tunnel>.ngrok-free.dev/mcp

# 5. Run all three services
bun run dev
```

Open [http://localhost:3000](http://localhost:3000) → **Start Conversation** →
ask "what time is it?".

### Working from a clone

If you cloned this repo (rather than scaffolding via the Agora CLI), the steps
above are complete as written: `bun run setup` creates both Python venvs and
installs web dependencies, then `bun run dev` brings up all three services. You
still need Agora credentials in `server/.env.local` and a public `MCP_ENDPOINT`
tunnel before a conversation can connect.

Services:

- Frontend — http://localhost:3000
- Backend — http://localhost:8000
- MCP server — http://localhost:8001
- API docs — http://localhost:8000/docs

## Deploy

Deploy `web` (Next.js) and `server` (a reachable FastAPI backend). Set
`AGENT_BACKEND_URL` in the web deployment so the Next rewrites reach the backend.

A multi-process Docker image is published to
`ghcr.io/AgoraIO-Conversational-AI/recipe-agent-mcp` on `v*` tags. It bundles
the agent backend (:8000) **and** the MCP server (:8001) in one image. To host
the single-image demo, expose :8001 publicly and point `MCP_ENDPOINT` at it. A
local `docker run` still needs a tunnel, because Agora cloud cannot reach
`localhost`. The bundled mock MCP server is a development stand-in you replace
with your own tools.

## Environment variables

Backend env file: [`server/.env.example`](server/.env.example).

| Variable | Required | Default | Notes |
| --- | :---: | :---: | --- |
| `AGORA_APP_ID` | Yes | — | Agora Console → Project → App ID |
| `AGORA_APP_CERTIFICATE` | Yes | — | Agora Console → Project → App Certificate |
| `MCP_ENDPOINT` | Yes | — | **Public** URL of your `mcp/` server (e.g. `https://<tunnel>/mcp`). Agora cloud calls it; cannot be `localhost`. |
| `OPENAI_MODEL` | | `gpt-4o-mini` | Model name for the managed OpenAI vendor |
| `OPENAI_API_KEY` | | — | Optional — Agora manages the OpenAI key (keyless by default) |
| `AGENT_GREETING` | | built-in | Optional opening line override |
| `PORT` | | `8000` | Agent backend port |
| `MCP_PORT` (mcp/.env.local) | | `8001` | Port for the MCP server |
| `AGENT_BACKEND_URL` (web deploy) | Yes (deploy) | — | Required when deploying `web` |

## Commands

```bash
bun run setup            # install web deps + create server/ and mcp/ venvs
bun run dev              # run mcp (:8001) + backend (:8000) + web (:3000)

bun run doctor           # prerequisite check (no creds needed)
bun run doctor:local     # + .env.local + credentials + MCP_ENDPOINT checks

bun run verify           # web-only gate (no Agora creds needed)
bun run verify:local     # full local gate: backend compile + web build
bun run clean            # remove venvs and build artifacts
```

Tests run standalone (no Agora cloud needed): `pytest` in `server/` and `mcp/`,
plus `bun run verify` in `web/`. CI runs them on Linux/macOS/Windows × Python
3.10 & 3.13.

## Architecture

```
Browser (localhost:3000)
  │  fetch /api/*
  ▼
Next.js  ──rewrite──▶  Agent backend  (server/, localhost:8000)
                          │  starts agent session (OpenAI vendor + mcp_servers)
                          ▼
                       Agora ConvoAI Cloud
                          │  user speech → Deepgram STT (managed)
                          │  OpenAI LLM (managed, keyless) → emits tool call
                          │  POST <MCP_ENDPOINT>   (streamable-http)
                          ▼
                       MCP server  (mcp/, localhost:8001)
                          ▲  public via ngrok tunnel
                          │  returns tool result → LLM speaks it
                          ▼
                       Agora ConvoAI Cloud → MiniMax TTS (managed) → user hears speech
                                          → RTM transcript / metrics → web UI
```

The browser only ever calls Next `/api/*`, which rewrites to the agent backend.
The agent backend owns Agora tokens and agent lifecycle. The **MCP server** is
separate because Agora cloud — not the browser — calls it, so it must be
publicly reachable. See [ARCHITECTURE.md](./ARCHITECTURE.md).

## What You Get

- A **Next.js** web client (:3000) that drives the RTC/RTM lifecycle and only
  ever calls `/api/*`.
- A **FastAPI** agent backend (:8000) that owns Agora token generation and the
  agent session lifecycle.
- The `/api/get_config` · `/api/startAgent` · `/api/stopAgent` contract between
  the web client and the backend (Next rewrites, no Route Handlers).
- Agora-managed keyless OpenAI with `mcp_servers` + `enable_tools` — Agora cloud
  orchestrates the FastMCP `get_time` tool without any OpenAI API key on your end.
- A **zero-key mock** MCP server so the full pipeline runs with no LLM API key.

## How It Works

1. The browser calls `/api/get_config`, which Next rewrites to the backend; the
   backend mints an Agora token from `AGORA_APP_ID` + `AGORA_APP_CERTIFICATE`.
2. The browser joins the RTC channel, then calls `/api/startAgent`; the backend
   starts an agent session using the managed `OpenAI` vendor with `mcp_servers`
   pointing at the public `MCP_ENDPOINT`.
3. The user speaks. Agora runs STT (Deepgram), then sends the transcript to the
   managed OpenAI LLM.
4. When the LLM emits a tool call (e.g. `get_time`), Agora cloud issues a
   streamable-HTTP request to `MCP_ENDPOINT`. The `mcp/` FastMCP server runs the
   tool and returns the result.
5. Agora feeds the tool result back to the LLM, which speaks the reply. Agora
   runs TTS (MiniMax) and plays it back in the channel.
6. `/api/stopAgent` ends the session.

### Replacing the mock

Add tools in [`mcp/src/mcp_server.py`](mcp/src/mcp_server.py). Each function
decorated with `@mcp.tool()` is automatically registered. The mock `get_time`
tool needs no external credentials — replace or extend it with your own logic.

## Repo Map

- `web/` — Next.js frontend (:3000); RTC/RTM lifecycle and UI.
- `server/` — FastAPI agent backend (:8000); Agora tokens + agent lifecycle, managed OpenAI vendor with `mcp_servers`.
- `mcp/` — FastMCP streamable-HTTP server (:8001) that Agora cloud calls when the LLM emits a tool call; no `agora-agents` dependency.
- `ARCHITECTURE.md` — system shape and component boundaries.
- `AGENTS.md` — guide for coding agents working in this repo.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Agent starts but never responds to "what time is it?" | `MCP_ENDPOINT` is not public or the `/mcp` path is wrong. Use your ngrok URL. |
| `doctor:local` warns about localhost | Replace the local URL with your public tunnel URL. |
| Local calls fail under a global proxy | Configure the proxy to send `127.0.0.1` and `localhost` DIRECT. |

## More Docs

- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [AGENTS.md](./AGENTS.md)

## License

Released under the [MIT License](./LICENSE).
