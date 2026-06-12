import os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
import mcp_server as srv  # noqa: E402

def test_current_time_message():
    msg = srv.current_time_message()
    assert "current server time" in msg.lower()
    assert re.search(r"\d{2}:\d{2}:\d{2}", msg)
