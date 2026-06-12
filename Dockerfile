# syntax=docker/dockerfile:1
FROM python:3.12-slim-bookworm AS runtime

# Run as a non-root user (created before any COPY so --chown can reference it).
RUN useradd --create-home --uid 10001 app
WORKDIR /app

# Dependencies for the FastAPI backend AND the bundled FastMCP server.
COPY server/requirements.txt /tmp/server-req.txt
COPY mcp/requirements.txt /tmp/mcp-req.txt
RUN pip install --no-cache-dir -r /tmp/server-req.txt -r /tmp/mcp-req.txt

# Sources + the supervising entrypoint, owned by the runtime user.
COPY --chown=app:app server/src /app/server/src
COPY --chown=app:app mcp/src /app/mcp/src
COPY --chown=app:app docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

ENV RPG_DB_PATH=/tmp/rpg.db
USER app

# server.py binds :8000 ($PORT); the MCP server binds :8001 ($MCP_PORT). Both 0.0.0.0.
EXPOSE 8000 8001
ENTRYPOINT ["/app/docker-entrypoint.sh"]
