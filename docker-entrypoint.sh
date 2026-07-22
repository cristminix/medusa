#!/bin/sh
set -e

# Apps are built into the image; this only starts the processes.

# Default keepalive timeout for long-lived connections
KEEPALIVE=${KEEPALIVE_TIMEOUT:-70000}

start_app() {
  cd "/app/apps/$1" || exit 1
  npx next start -p "$2" --keepAliveTimeout "$KEEPALIVE" &
}

start_app api-reference 3000
start_app book          3001
start_app ui            3002
start_app resources     3003
start_app user-guide    3004
start_app bloom         3005
start_app cloud         3006

# Start nginx in the foreground (keeps the container alive)
exec nginx -g "daemon off;"
