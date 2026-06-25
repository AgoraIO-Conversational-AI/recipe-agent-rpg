# Deep Dive — MCP Tool Config

> **When to Read This:** You are changing the Dungeon Master's model, system prompt, `MCP_ENDPOINT`, `mcp_servers` wiring, VAD config, `output_audio_codec`, or any session option in `agent.py`. For the high-level picture, start at [02_architecture](../02_architecture.md).

This recipe uses a cascading STT→LLM→TTS vendor pipeline where the LLM stage is the Agora-managed `OpenAI` vendor with `mcp_servers` pointing at the public FastMCP game server. The vendor pipeline lives in `server/src/agent.py`; the `mcp_servers` list builder lives in `server/src/mcp_config.py`.

## The vendor pipeline

Built inside `Agent.start()`:

```python
llm = OpenAI(
    api_key=self.openai_api_key,       # None → Agora-managed (keyless)
    model=self.openai_model,            # OPENAI_MODEL, default "gpt-4o-mini"
    system_messages=[{"role": "system", "content": "...DM system prompt..."}],
    mcp_servers=build_mcp_servers(self.mcp_endpoint),
    greeting_message=self.greeting,    # AGENT_GREETING or built-in default
)
stt = DeepgramSTT(model="nova-3", language="en")
tts = MiniMaxTTS(model="speech_2_6_turbo", voice_id="English_captivating_female1")

agora_agent = AgoraAgent(...).with_stt(stt).with_llm(llm).with_tts(tts)
```

## The `mcp_servers` list (`mcp_config.py`)

`build_mcp_servers(endpoint, name="rpg")` returns:

```python
[{"name": "rpg", "endpoint": endpoint, "transport": "streamable_http"}]
```

- `endpoint` is `MCP_ENDPOINT` — a **public** URL (e.g. `https://<tunnel>.ngrok-free.dev/mcp`). Agora cloud calls it directly.
- `transport` must be `"streamable_http"` (underscore) for the Agora SDK. FastMCP's own transport name uses a hyphen — these are different conventions.
- `test_mcp_config.py` asserts the exact output shape.

## VAD (turn detection)

Turn detection is configured on `AgoraAgent(...)` directly (not on the vendor, unlike the realtime recipe):

```python
agora_agent = AgoraAgent(
    ...
    turn_detection={
        "config": {
            "speech_threshold": 0.5,
            "start_of_speech": {
                "mode": "vad",
                "vad_config": {"interrupt_duration_ms": 160, "prefix_padding_ms": 300},
            },
            "end_of_speech": {
                "mode": "vad",
                "vad_config": {"silence_duration_ms": 480},
            },
        },
    },
    advanced_features={"enable_rtm": True, "enable_tools": True},
    ...
)
```

`enable_tools: True` is required for MCP tool calling to work.

## Session `parameters`

Set in `Agent.start()` and passed to `AgoraAgent`:

| Key                    | Value    | Why                                                  |
| ---------------------- | -------- | ---------------------------------------------------- |
| `audio_scenario`       | `chorus` | Ultra-low-latency profile for web clients.           |
| `data_channel`         | `rtm`    | Transcript + metrics delivered over RTM.             |
| `enable_error_message` | `true`   | Surface agent-side errors to the client.             |
| `enable_metrics`       | `true`   | Emit pipeline metrics to the UI.                     |
| `output_audio_codec`   | optional | Forwarded from `POST /startAgent` `parameters`.      |

## How it is wired into the session

```python
session = agora_agent.create_async_session(
    channel=channel_name,
    agent_uid=str(agent_uid),
    remote_uids=[str(user_uid)],
    enable_string_uid=False,
    idle_timeout=30,
    expires_in=3600,
)
agent_id = await session.start()    # stored in self._sessions[agent_id]
```

## Stop fallback

`Agent.stop()` first tries `session.stop()` from `_sessions`. If the session is not found (e.g. after a restart), it falls back to `self.client.stop_agent(agent_id)` via the stateless Agora client.

## Changing the DM system prompt

Edit the `system_messages` list in `Agent.start()`. The current prompt instructs the DM to:
- Narrate in 1–3 sentences.
- Call the correct tool for every mechanic (never invent dice, HP, or loot).
- Ask for a class if the player has no character yet.

After editing, run `bun run verify:backend` + `cd server && pytest tests -v`.

## Related L1

- [02_architecture](../02_architecture.md) · [06_interfaces](../06_interfaces.md) · [07_gotchas](../07_gotchas.md)
