"""MCP server (streamable-HTTP) exposing one mock tool. Agora cloud calls this
when the LLM emits a tool call. Replace get_time with your own tools."""
import datetime
import os

from mcp.server.fastmcp import FastMCP

MCP_PORT = int(os.getenv("MCP_PORT", "8001"))
mcp = FastMCP("recipe-agent-mcp", host="0.0.0.0", port=MCP_PORT)


def current_time_message() -> str:
    """Pure, testable helper: the message the get_time tool returns."""
    now = datetime.datetime.now().strftime("%H:%M:%S")
    return f"The current server time is {now}."


@mcp.tool()
def get_time() -> str:
    """Return the current server time. Call this when the user asks what time it is."""
    msg = current_time_message()
    print(f"[MCP TOOL CALLED] get_time -> {msg}", flush=True)
    return msg


if __name__ == "__main__":
    print(f"Starting MCP server (streamable-http) on :{MCP_PORT}/mcp", flush=True)
    mcp.run(transport="streamable-http")
