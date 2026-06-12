# Architecture — MCP Recipe

Three processes. The browser talks only to Next.js `/api/*`, which rewrites to
the agent backend. The agent backend owns Agora tokens and agent lifecycle. The
MCP server is a separate service that **Agora cloud** calls directly to execute
tool calls.

## Request flow

```
Browser
  │  GET /api/get_config            → token + channel/UIDs
  │  POST /api/startAgent           → start agent session
  ▼
Next.js  (rewrites /api/* → AGENT_BACKEND_URL)
  ▼
Agent backend (server/, :8000)
  │  builds session with OpenAI(mcp_servers=[{endpoint: MCP_ENDPOINT}])
  ▼
Agora ConvoAI Cloud
  │  user speech → Deepgram STT (managed)
  │  managed OpenAI LLM (keyless) → emits get_time tool call
  │  POST <MCP_ENDPOINT>   (streamable-http transport)
  ▼
MCP server (mcp/, :8001, public via tunnel)
  │  executes get_time() → returns current time string
  ▼
Agora ConvoAI Cloud → LLM incorporates result → speaks answer
                     → MiniMax TTS (managed) → user hears speech
                     → RTM transcript / metrics → web UI
```

`POST /api/stopAgent { agentId }` ends the session.

## Why a separate MCP server

`server/` and `mcp/` are split because of an **exposure asymmetry**:

- `mcp/` must be reachable by **Agora cloud over the public internet** (hence
  the ngrok tunnel). It is the component you extend with your own tools, and it
  has no Agora dependency.
- `server/` only needs to be reachable by your web tier. It holds the Agora App
  Certificate and all token logic.

In production the two could be co-deployed, but they are kept separate here to
make that boundary — and the public-exposure requirement — explicit.

## Distinct from recipe-agent-tool-calling

In `recipe-agent-tool-calling` the tools run **inside** the `llm/` endpoint:
the agent's custom LLM proxy intercepts tool calls and handles them locally. In
this recipe Agora cloud orchestrates the tools on the **separate `mcp/`
server** via the MCP protocol — the managed OpenAI vendor issues the tool call,
Agora invokes `MCP_ENDPOINT`, and the result flows back to the LLM.

## API (agent backend, port 8000)

| Endpoint | Method | Description |
| --- | --- | --- |
| `/get_config` | GET | Token + channel/UID config |
| `/startAgent` | POST | Start the agent session |
| `/stopAgent` | POST | Stop the agent by `agent_id` |

The browser calls these as `/api/*`; Next rewrites them to `AGENT_BACKEND_URL`.

## Auth

- Browser → agent backend: none (local dev).
- Agent backend → Agora cloud: Token007, generated from `AGORA_APP_ID` +
  `AGORA_APP_CERTIFICATE`.
- Agora cloud → MCP server: streamable-http (no auth on the mock; add it for
  production use).
- OpenAI: Agora-managed (keyless) — `OPENAI_API_KEY` is optional.
