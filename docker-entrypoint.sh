#!/bin/sh
# Supervise the bundled FastMCP server (:8001) + the agent backend (:8000).
# POSIX sh (the slim image has no bash -> no `wait -n`). Docker/Linux only: uses /proc.

shutting_down=0
term() {
  shutting_down=1
  kill "$mock_pid" "$server_pid" 2>/dev/null
}
trap term TERM INT

python /app/mcp/src/mcp_server.py &
mock_pid=$!

python /app/server/src/server.py &
server_pid=$!

alive() {
  [ -d "/proc/$1" ] || return 1
  st=$(awk '/^State:/ { print $2; exit }' "/proc/$1/status" 2>/dev/null)
  [ -n "$st" ] && [ "$st" != "Z" ]
}

while alive "$mock_pid" && alive "$server_pid"; do
  sleep 1
done

kill "$mock_pid" "$server_pid" 2>/dev/null

if [ "$shutting_down" -eq 0 ]; then
  echo "docker-entrypoint: a supervised process exited unexpectedly" >&2
  exit 1
fi
exit 0
