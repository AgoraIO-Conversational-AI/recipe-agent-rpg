# Progressive Disclosure — Test Results

> Test run for `recipe-agent-rpg` progressive disclosure docs.
> Date: 2026-06-25 · Standard: AgoraIO-Community/ai-devkit progressive-disclosure.

## Step 1 — Structural checks

| Check                                                   | Result              |
| ------------------------------------------------------- | ------------------- |
| `L0_repo_card.md` ≤ 50 lines                            | Pass (36)           |
| All 8 L1 files present                                  | Pass                |
| Each L1 has purpose blockquote + Related Deep Dives     | Pass (8/8)          |
| L1 line counts in 80–200 target                         | **Below target** (43–115) — see note |
| L2 `_index.md` present                                  | Pass                |
| Each L2 deep-dive opens with "When to Read This" callout| Pass (2/2)          |
| Relative links resolve (`docs/ai/` + AGENTS.md)         | Pass (33/33, 0 broken) |
| AGENTS.md has How to Load / Git Conventions / Doc Commands | Pass             |

**Note on L1 line counts:** files are table-dense and information-complete but
run 43–115 lines, under the 80–200 soft target. The standard favors tables over
prose and warns against bloat, so they were left concise rather than padded.
Accepted deviation; revisit if a section needs more depth.

## Step 2/3 — Question runs

Questions span the five standard categories. Each answer was checked against the
repo source before being marked Pass. "Level" is the lowest disclosure level
that fully answers the question.

### Setup & Build

| # | Question | Expected answer | Source of truth | Level | Status |
|---|----------|-----------------|-----------------|-------|--------|
| 1 | How do I install and run it locally? | `bun run setup`, expose backend via ngrok, set `MCP_ENDPOINT`, then `bun run dev`. | `L1/01_setup.md` ↔ `package.json`, `README.md` | L1 | Pass |
| 2 | Which env vars are required? | `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`, `MCP_ENDPOINT`. | `L1/01_setup.md`, `06_interfaces.md` ↔ `agent.py`, `.env.example` | L1 | Pass |
| 3 | Is this zero-key? | Yes — `OPENAI_API_KEY` is optional; Agora manages it. `MCP_ENDPOINT` is the notable required extra. | `L1/01_setup.md`, `08_security.md` ↔ `README.md`, `agent.py` | L1 | Pass |

### Test & Run

| # | Question | Expected answer | Source of truth | Level | Status |
|---|----------|-----------------|-----------------|-------|--------|
| 4 | How do I run backend tests without cloud creds? | `cd server && pytest tests -v`; `conftest.py` fakes env; game tests use temp SQLite files + seeded RNG. | `L1/04_conventions.md`, `01_setup.md` ↔ `tests/conftest.py`, `test_rpg.py` | L1 | Pass (ran: 11 passed) |
| 5 | What's the narrowest gate for a web-only change? | `bun run verify:web`. | `L1/05_workflows.md` ↔ `package.json` | L1 | Pass |
| 6 | How do I test deterministic game outcomes? | Set `RPG_SEED` to a fixed integer; tests pass an explicit `random.Random(seed)` to game functions. | `L1/04_conventions.md` ↔ `game.py`, `test_rpg.py` | L1 | Pass |

### Conventions

| # | Question | Expected answer | Source of truth | Level | Status |
|---|----------|-----------------|-----------------|-------|--------|
| 7 | What response shape do backend routes use? | `{ code, msg, data }`; `data` only when there's a payload. | `L1/04_conventions.md`, `06_interfaces.md` ↔ `server.py` | L1 | Pass |
| 8 | Why is `game.py` kept free of MCP imports? | It is a standalone unit-testable engine; MCP imports would couple it to the FastMCP stack and break test isolation. | `L1/04_conventions.md`, `07_gotchas.md` ↔ `game.py` (no mcp import) | L1 | Pass |
| 9 | What are the commit/branch conventions? | Conventional commits `type: description`; branches `type/short-description`; no AI tool names. | `AGENTS.md` Git Conventions | L1 | Pass |

### Development

| # | Question | Expected answer | Source of truth | Level | Status |
|---|----------|-----------------|-----------------|-------|--------|
| 10 | How do I add a new game tool? | Add logic to `game.py` (no MCP import), add `@mcp.tool()` in `mcp_server.py`, add tests in `test_rpg.py`, update DM system prompt in `agent.py`. | `L1/05_workflows.md` ↔ `mcp_server.py`, `game.py`, `agent.py` | L1 | Pass |
| 11 | Where is the `/api/*` boundary defined and what must I not add? | Rewrites in `web/next.config.ts`; never add `app/api/**/route.ts` for agent/token logic. | `L1/04_conventions.md`, `07_gotchas.md` ↔ `next.config.ts`, `verify-api-contracts.ts` | L1 | Pass |
| 12 | Why can't `MCP_ENDPOINT` be localhost? | Agora cloud (not the local server) calls it — it must be publicly reachable. | `L1/07_gotchas.md` ↔ `agent.py` (`AGORA_APP_ID` + `MCP_ENDPOINT` check), `AGENTS.md` | L1 | Pass |

### Deep Dive

| # | Question | Expected answer | Source of truth | Level | Status |
|---|----------|-----------------|-----------------|-------|--------|
| 13 | What is the exact shape of the `mcp_servers` list passed to the agent? | `[{"name": "rpg", "endpoint": MCP_ENDPOINT, "transport": "streamable_http"}]`; `streamable_http` uses underscore (Agora SDK convention). | `L2/mcp_tool_config.md` ↔ `mcp_config.py`, `test_mcp_config.py` | L2 | Pass |
| 14 | What is the SQLite schema and how does combat state persist across connections? | Three tables (`character`, `enemy`, `settings`), each capped at 1 row; each MCP tool opens its own connection via `get_db()`. | `L2/game_engine.md` ↔ `game.py` `get_db()` | L2 | Pass |
| 15 | How does stop survive a backend restart? | `_sessions` is in-memory; missing session falls back to `self.client.stop_agent(agent_id)` via the stateless Agora client. | `L2/mcp_tool_config.md` (stop fallback) ↔ `agent.py` `stop()` | L2 | Pass |

## Step 4 — Analysis

- All 15 questions answered at the expected disclosure level (12 at L1, 3 at L2).
  No "correct but needed L2 unnecessarily" or "wrong/missing L2" cases.
- No missing-coverage findings; no broken references.
- One soft deviation: several L1 files run below the 80–200 line target (accepted; concise/table-dense).
- `verify-local-llm.ts` in `web/scripts/` is a legacy script from tool-calling recipe lineage; it is not wired into any `package.json` verify script and does not affect CI — noted in `03_code_map.md`.

## Step 5 — Summary

| Category       | Questions | Pass | Notes |
| -------------- | :-------: | :--: | ----- |
| Setup & Build  | 3 | 3 | — |
| Test & Run     | 3 | 3 | backend tests executed: 11 passed |
| Conventions    | 3 | 3 | — |
| Development    | 3 | 3 | — |
| Deep Dive      | 3 | 3 | resolved at L2 as designed |
| **Total**      | **15** | **15** | — |

## Step 6 — Fixes / Retest

No failing questions; no fixes required. Evidence executed during this run:

- `pytest tests -v` (throwaway venv `/tmp/v_rpg`, Python 3.14, `requirements.txt` + `requirements-dev.txt`) → `11 passed`.
- Relative link check → `33 checked, 0 broken`.
- Venv removed: `rm -rf /tmp/v_rpg`.
