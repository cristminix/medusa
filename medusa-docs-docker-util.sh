#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$DIR/docker-compose.yml"

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  build              Build the docs image
  start              Start the docs container in the background
  stop               Stop the docs container
  restart            Restart the docs container
  status             Show container status
  logs               Tail logs from the docs container
  down               Stop and remove the docs container
  down-clean         Stop and remove container + image

EOF
  exit 0
}

[ $# -eq 0 ] && usage

CMD="$1"

case "$CMD" in
  build)
    docker compose -f "$COMPOSE_FILE" build
    ;;
  start)
    docker compose -f "$COMPOSE_FILE" up -d
    ;;
  stop)
    docker compose -f "$COMPOSE_FILE" stop
    ;;
  restart)
    docker compose -f "$COMPOSE_FILE" restart
    ;;
  status)
    docker compose -f "$COMPOSE_FILE" ps
    ;;
  logs)
    docker compose -f "$COMPOSE_FILE" logs -f
    ;;
  down)
    docker compose -f "$COMPOSE_FILE" down
    ;;
  down-clean)
    docker compose -f "$COMPOSE_FILE" down --rmi all
    ;;
  *)
    usage
    ;;
esac
