# Deep Dive — Game Engine

> **When to Read This:** You are adding or modifying a game tool, changing combat or character logic, debugging game state, or working with `RPG_SEED` for deterministic testing. For the high-level MCP wiring, see [mcp_tool_config](mcp_tool_config.md).

`server/src/game.py` is a pure game engine — no MCP import, fully unit-testable in isolation. All dice rolling and game state mutation happen here; `mcp_server.py` delegates to it.

## SQLite schema

`get_db(path)` creates (if needed) and returns a connection. Three tables:

| Table       | Columns                                          | Constraint           |
| ----------- | ------------------------------------------------ | -------------------- |
| `character` | `id`, `class`, `hp`, `max_hp`, `gold`, `inventory` (JSON) | `id = 1` (one row) |
| `enemy`     | `id`, `name`, `hp`, `atk`                        | `id = 1` (one row)  |
| `settings`  | `key`, `value`                                   | PK = `key`           |

`settings` is seeded with `('mode', 'narration')` on first open. Mode transitions: `narration ↔ combat`.

Each tool opens its own connection via `game.get_db()` (called by `mcp_server._run()`) and closes it after. Connections use `check_same_thread=False`.

## Character classes

| Class    | HP | Die | Spell        |
| -------- | -- | --- | ------------ |
| warrior  | 30 | d8  | shield bash  |
| mage     | 18 | d6  | fireball     |
| rogue    | 22 | d6  | backstab     |
| cleric   | 24 | d6  | smite        |

`create_character` deletes both `character` and `enemy` rows, resets mode to `narration`.

## Combat flow

```
[narration]  start_encounter()  → random enemy spawned, mode → "combat"
[combat]     attack() / cast_spell(name)
               → roll hero die (spell: die + 2)
               → reduce enemy HP
               → if enemy HP ≤ 0: loot awarded, enemy deleted, mode → "narration"
               → else: enemy counterattacks (roll enemy.atk), reduce hero HP
               → if hero HP ≤ 0: character + enemy deleted, mode → "narration", game over
[combat]     flee()  → enemy cleared, mode → "narration"
```

Encounters are chosen randomly from `ENCOUNTERS = [goblin, skeleton, orc]`. Loot is chosen randomly from `LOOT`.

## Dice and `RPG_SEED`

```python
_seed = os.getenv("RPG_SEED")
_RNG = random.Random(int(_seed)) if _seed not in (None, "") else random.Random()
```

- Module-level `_RNG` is used for all `roll()` calls by default.
- Test functions that need deterministic outcomes pass their own `random.Random(seed)` explicitly (see `test_rpg.py`).
- `RPG_SEED` makes the entire session deterministic from startup — useful for manual testing, not for production.

## `_resolve()` — combat resolution helper

`attack()` and `cast_spell()` both call `_resolve(conn, label, die, rng)`:

1. Roll `die` for hero attack → reduce enemy HP.
2. If enemy HP ≤ 0: pick loot, update character inventory/gold, delete enemy, mode → `narration`, return victory message.
3. Otherwise: roll `enemy.atk` for counterattack → reduce hero HP.
4. If hero HP ≤ 0: delete character + enemy, mode → `narration`, return game-over message.
5. Otherwise: update both HP, return mid-combat message with remaining HP.

## Tool return values

Each tool returns a plain-English string for the DM to narrate. Examples:

- `create_character("warrior")` → `"You are a warrior with 30 HP; your signature move is shield bash. Your adventure begins."`
- `start_encounter()` → `"A goblin appears (12 HP)! Attack or cast your spell."`
- `attack()` → `"Your attack rolls 6 — the goblin drops to 6 HP, then strikes back for 3. You have 27 HP left."`
- `flee()` → `"You flee from the goblin and slip into the shadows."`

The DM is instructed to narrate only what the tool reported and not to invent numeric values.

## Testing

`server/tests/test_rpg.py` uses temporary SQLite files per test case:

```python
def fresh():
    path = os.path.join(tempfile.mkdtemp(), "rpg.db")
    return game.get_db(path), path
```

Tests pass explicit `random.Random(seed)` to `start_encounter` and `attack` for reproducible outcomes. `test_seeded_combat_is_deterministic` runs the same sequence twice and asserts identical results.

## Related L1

- [03_code_map](../03_code_map.md) · [04_conventions](../04_conventions.md) · [07_gotchas](../07_gotchas.md)
