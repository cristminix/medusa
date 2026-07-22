# Docker Compose Usage

## Prerequisites

- Docker 20+
- Docker Compose v2

## Quick Start

```bash
# Build the image (10-20 min first run; all apps are compiled here)
./medusa-docs-docker-util.sh build

# Start the container
./medusa-docs-docker-util.sh start

# Check status
./medusa-docs-docker-util.sh status
```

Open `http://localhost:8082` in your browser.

## Architecture

A single image contains all seven Next.js apps plus nginx. The apps are built
at image build time, so starting the container is fast — `start` only launches
the seven `next start` processes and nginx, which reverse-proxies them on
port 80.

## Commands

| Command | Description |
|---|---|
| `./medusa-docs-docker-util.sh build` | Build the docs image |
| `./medusa-docs-docker-util.sh start` | Start the container in the background |
| `./medusa-docs-docker-util.sh stop` | Stop the container |
| `./medusa-docs-docker-util.sh restart` | Restart the container |
| `./medusa-docs-docker-util.sh status` | Show container status |
| `./medusa-docs-docker-util.sh logs` | Tail logs (all apps share one stream) |
| `./medusa-docs-docker-util.sh down` | Stop and remove the container |
| `./medusa-docs-docker-util.sh down-clean` | Stop, remove container and image |

## Apps and Ports

| App | Port | URL |
|---|---|---|
| book | 3001 | `http://localhost:8082/` |
| api-reference | 3000 | `http://localhost:8082/api` |
| ui | 3002 | `http://localhost:8082/ui` |
| resources | 3003 | `http://localhost:8082/resources` |
| user-guide | 3004 | `http://localhost:8082/user-guide` |
| bloom | 3005 | `http://localhost:8082/bloom` |
| cloud | 3006 | `http://localhost:8082/cloud` |

## Troubleshooting

**Port conflict**: If `8082` is in use, change the nginx port in `docker-compose.yml` from `8082:80` to another port.

**502 Bad Gateway**: The container is up but an app hasn't finished starting, or
one of the `next start` processes died. Check `logs` for the failing port.

**Out of memory during build**: Seven Next.js builds run in one layer. The
Dockerfile sets `NODE_OPTIONS=--max-old-space-size=6144`; if the build still
dies, raise Docker's memory limit or lower turbo's concurrency in the build
step to `--concurrency=1`.

**`yarn install --immutable` fails**: `www/yarn.lock` is out of sync with a
workspace `package.json`. Run `yarn install` in `www/` locally and commit the
updated lockfile.

**Adding or removing a workspace**: The deps stage in the `Dockerfile` copies
each workspace `package.json` explicitly. A new workspace needs a matching
`COPY` line there, or the install will resolve against an incomplete tree.
