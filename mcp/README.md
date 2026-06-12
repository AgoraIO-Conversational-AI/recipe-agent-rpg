# MCP Server — recipe-agent-mcp

FastMCP streamable-HTTP server that Agora cloud calls when the managed OpenAI
LLM emits a tool call. It exposes one mock tool (`get_time`) and is designed to
be extended with your own tools.

## What this is

Agora's Conversational AI platform supports MCP (Model Context Protocol) tool
calling. When you configure `mcp_servers` in the agent's `OpenAI` vendor, Agora
cloud will POST to `MCP_ENDPOINT` whenever the LLM issues a tool call. This
server is that endpoint.

It is intentionally separate from the agent backend (`server/`) because Agora
cloud — not the browser or the backend — calls it, so it must be publicly
reachable (e.g. via an ngrok tunnel).

## Run (via repo root)

```bash
# Start just the MCP server (after bun run setup):
bun run mcp
```

Or with `bun run dev` (starts mcp + backend + web together).

## Run standalone

```bash
cd mcp
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
MCP_PORT=8001 python src/mcp_server.py
```

The server listens at `http://0.0.0.0:<MCP_PORT>/mcp`.

## Environment

`mcp/.env.example` is the template. Copy it to `mcp/.env.local`:

| Variable | Default | Notes |
| --- | --- | --- |
| `MCP_PORT` | `8001` | Port for the MCP server |

No API keys required. The mock `get_time` tool needs no external credentials.

## Replacing the mock

Add tools in `mcp/src/mcp_server.py`. Each function decorated with
`@mcp.tool()` is automatically registered and exposed to Agora cloud:

```python
@mcp.tool()
def my_tool(param: str) -> str:
    """Description that the LLM uses to decide when to call this tool."""
    return do_something(param)
```

Update the system message in `server/src/agent.py` to tell the LLM when to
call your new tool.

## Tests

```bash
cd mcp && source venv/bin/activate
python -m pytest tests/ -q
```

The test imports `current_time_message()` directly — no server process needed.
