# MCP Game Server — recipe-agent-rpg

FastMCP streamable-HTTP server that Agora cloud calls when the managed Dungeon
Master LLM emits a tool call. It exposes 6 self-contained game tools backed by
SQLite and is the component you extend to add new game mechanics.

## What this is

The `mcp/` server is the RPG game engine. When the Dungeon Master decides to
call a game tool (e.g. `attack()`), Agora cloud POSTs to `MCP_ENDPOINT`. This
server receives that request, runs the tool (rolling dice, updating SQLite,
computing loot), and returns a plain-English result for the DM to narrate.

It is intentionally separate from the agent backend (`server/`) because Agora
cloud — not the browser or the backend — calls it, so it must be publicly
reachable (e.g. via an ngrok tunnel). It has no `agora-agents` dependency.

## The 6 tools

| Tool | What it does |
| --- | --- |
| `create_character(char_class)` | Create/reset hero; `char_class` is warrior, mage, rogue, or cleric |
| `get_character()` | Return class, HP, gold, inventory, and current mode (narration/combat) |
| `start_encounter()` | Spawn a random enemy and switch to combat mode |
| `attack()` | Roll the hero's die, deal damage, enemy counterattacks; handles death + loot |
| `cast_spell(name)` | Cast the hero's class spell (bonus die); same resolution as attack |
| `flee()` | Exit combat immediately, clear the enemy, return to narration mode |

Each tool is **self-contained** — dice are rolled inside `game.py`, not by the
LLM. No tool-call chaining is needed; one player utterance maps to at most one
tool call.

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
| `MCP_PORT` | `8001` | Port for the MCP game server |
| `RPG_DB_PATH` | `rpg.db` | SQLite database path (relative to `mcp/`) |
| `RPG_SEED` | — | Optional integer for deterministic dice (used by tests) |

No external API keys required.

## Adding tools

Add game functions in `mcp/src/game.py` (pure Python, no MCP import), then
register them in `mcp/src/mcp_server.py` with `@mcp.tool()`:

```python
@mcp.tool()
def my_action() -> str:
    """Describe when the DM should call this action."""
    return _run(game.my_action)
```

Update the system message in `server/src/agent.py` to tell the DM when to use
the new tool.

## Tests

```bash
cd mcp && source venv/bin/activate
python -m pytest tests/ -q
```

8 tests cover all 6 tools plus a persistence test (write on one SQLite
connection, read on a fresh one). Tests use `RPG_SEED=42` for deterministic
dice outcomes — set it in your environment if running manually:

```bash
RPG_SEED=42 python -m pytest tests/ -q
```
