# Plan: Docker Compose for All Documentation Apps (Single Endpoint)

This plan creates a docker-compose setup that runs all 7 documentation Next.js
apps inside Docker containers, with nginx as a reverse proxy so every app is
accessible from a single URL (`http://localhost`), differentiated by its
`NEXT_PUBLIC_BASE_PATH`.

---

## 1. Overview

### Apps and their assigned ports / base paths

| App | Package Name | Container Port | BASE_PATH |
|---|---|---|---|
| `api-reference` | `api-reference` | `3000` | `/api` |
| `book` | `book` | `3001` | _(root, no base path)_ |
| `ui` | `ui` | `3002` | `/ui` |
| `resources` | `resources` | `3003` | `/resources` |
| `user-guide` | `user-guide` | `3004` | `/user-guide` |
| `bloom` | `bloom` | `3005` | `/bloom` |
| `cloud` | `cloud` | `3006` | `/cloud` |

### How nginx routes requests

Nginx listens on port **80** and proxies incoming requests to the correct
container based on the URL path prefix:

```
Browser  -->  nginx:80
                |
                +-- /api/*          --> api-reference:3000
                +-- /resources/*    --> resources:3003
                +-- /ui/*           --> ui:3002
                +-- /user-guide/*   --> user-guide:3004
                +-- /cloud/*        --> cloud:3006
                +-- /bloom/*        --> bloom:3005
                +-- /* (everything) --> book:3001
```

---

## 2. Prerequisites

Before starting, make sure you have these installed on your machine:

- **Docker** (version 20 or newer)
- **Docker Compose** (v2, comes with Docker Desktop or as `docker compose` plugin)
- **Node.js** (>= 20)
- **Yarn** (v3, already configured in this repo)

Verify with:

```bash
docker --version
docker compose version
node --version    # should be >= 20
```

---

## 3. File Changes Summary

You will create **3 new files** and modify **7 existing .env files**.

### New files to create:

| File | Purpose |
|---|---|
| `www/Dockerfile` | Shared Docker image recipe for all 7 apps |
| `www/docker-compose.yml` | Defines all 8 services (7 apps + nginx) |
| `www/nginx.conf` | Nginx reverse-proxy routing rules |

### Existing files to modify:

| File | What to change |
|---|---|
| `apps/book/.env` | Change `NEXT_PUBLIC_BASE_URL` IP to `localhost` |
| `apps/api-reference/.env` | Change `NEXT_PUBLIC_BASE_URL` IP to `localhost` |
| `apps/ui/.env` | Change `NEXT_PUBLIC_BASE_URL` IP to `localhost` |
| `apps/resources/.env` | Change `NEXT_PUBLIC_BASE_URL` IP to `localhost` |
| `apps/user-guide/.env` | Change `NEXT_PUBLIC_BASE_URL` IP to `localhost` |
| `apps/bloom/.env` | Change `NEXT_PUBLIC_BASE_URL` IP to `localhost` |
| `apps/cloud/.env` | Change `NEXT_PUBLIC_BASE_URL` IP to `localhost` |

---

## 4. Step-by-Step Instructions

### Step 1: Create the Dockerfile

**Create file:** `/home/damar/projects/medusa/www/Dockerfile`

This one Dockerfile is shared by all 7 apps. Each app container uses the **same
image**, just running a different app inside.

```dockerfile
# ---- Build stage ----
FROM node:20-alpine AS builder

WORKDIR /build

# Copy root workspace files first (for yarn install)
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn/

# Copy the entire www workspace (needed because internal packages are dependencies)
COPY packages ./packages
COPY apps ./apps
COPY tsconfig.json ./
COPY turbo.json ./

# Install dependencies (builds internal packages too)
RUN yarn install --frozen-lockfile

# Build the internal shared packages
RUN yarn build:packages

# Expose a build argument so we can tell it WHICH app to build
ARG APP_NAME
ARG PORT

# Build the specific Next.js app in monorepo mode
RUN yarn workspace ${APP_NAME} build

# ---- Runtime stage (smaller final image) ----
FROM node:20-alpine AS runner

WORKDIR /app

# Accept arguments from the build stage
ARG APP_NAME
ARG PORT

# Copy built artifacts from the builder stage
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/apps/${APP_NAME}/.next ./.next
COPY --from=builder /build/apps/${APP_NAME}/package.json ./
COPY --from=builder /build/apps/${APP_NAME}/public ./public
COPY --from=builder /build/apps/${APP_NAME}/next.config.mjs ./

# Copy the internal packages that are needed at runtime
COPY --from=builder /build/packages ./packages
COPY --from=builder /build/apps ./apps

# Copy root workspace files
COPY --from=builder /build/package.json /build/yarn.lock /build/.yarnrc.yml ./
COPY --from=builder /build/.yarn ./.yarn/

# Set environment variable so Next.js knows what port to use
ENV PORT=${PORT}

EXPOSE ${PORT}

# Start the app with the monorepo-specific start command
CMD ["sh", "-c", "yarn workspace ${APP_NAME} start:monorepo"]
```

### Step 2: Update each app's .env file

For each of the 7 apps, change the IP in `NEXT_PUBLIC_BASE_URL` from
`http://10.10.0.3` to `http://localhost`. **Keep the port number exactly as
it is.**

#### 2a: `apps/api-reference/.env`

**Find this line (line 4):**
```
NEXT_PUBLIC_BASE_URL=http://10.10.0.3:3000
```
**Replace with:**
```
NEXT_PUBLIC_BASE_URL=http://localhost:3000
```

#### 2b: `apps/book/.env`

**Find this line (line 3):**
```
NEXT_PUBLIC_BASE_URL=http://10.10.0.3:3001
```
**Replace with:**
```
NEXT_PUBLIC_BASE_URL=http://localhost:3001
```

#### 2c: `apps/ui/.env`

**Find this line (line 3):**
```
NEXT_PUBLIC_BASE_URL=http://10.10.0.3:3002
```
**Replace with:**
```
NEXT_PUBLIC_BASE_URL=http://localhost:3002
```

#### 2d: `apps/resources/.env`

**Find this line (line 3):**
```
NEXT_PUBLIC_BASE_URL=http://10.10.0.3:3003
```
**Replace with:**
```
NEXT_PUBLIC_BASE_URL=http://localhost:3003
```

#### 2e: `apps/user-guide/.env`

**Find this line (line 3):**
```
NEXT_PUBLIC_BASE_URL=http://10.10.0.3:3004
```
**Replace with:**
```
NEXT_PUBLIC_BASE_URL=http://localhost:3004
```

#### 2f: `apps/bloom/.env`

**Find this line (line 3):**
```
NEXT_PUBLIC_BASE_URL=http://10.10.0.3:3005
```
**Replace with:**
```
NEXT_PUBLIC_BASE_URL=http://localhost:3005
```

#### 2g: `apps/cloud/.env`

**Find this line (line 3):**
```
NEXT_PUBLIC_BASE_URL=http://10.10.0.3:3006
```
**Replace with:**
```
NEXT_PUBLIC_BASE_URL=http://localhost:3006
```

### Step 3: Create the nginx configuration

**Create file:** `/home/damar/projects/medusa/www/nginx.conf`

This tells nginx how to route requests to each app based on the URL path.

```nginx
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Improve proxy performance
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 80;
        server_name localhost;

        # ---- Proxy /api and /api/* to the api-reference app ----
        location /api {
            proxy_pass         http://api-reference:3000;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade $http_upgrade;
            proxy_set_header   Connection "upgrade";
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto $scheme;
            proxy_set_header   X-Forwarded-Host $host;
            proxy_redirect     off;
        }

        # ---- Proxy /resources and /resources/* to the resources app ----
        location /resources {
            proxy_pass         http://resources:3003;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade $http_upgrade;
            proxy_set_header   Connection "upgrade";
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto $scheme;
            proxy_set_header   X-Forwarded-Host $host;
            proxy_redirect     off;
        }

        # ---- Proxy /ui and /ui/* to the ui app ----
        location /ui {
            proxy_pass         http://ui:3002;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade $http_upgrade;
            proxy_set_header   Connection "upgrade";
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto $scheme;
            proxy_set_header   X-Forwarded-Host $host;
            proxy_redirect     off;
        }

        # ---- Proxy /user-guide and /user-guide/* to the user-guide app ----
        location /user-guide {
            proxy_pass         http://user-guide:3004;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade $http_upgrade;
            proxy_set_header   Connection "upgrade";
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto $scheme;
            proxy_set_header   X-Forwarded-Host $host;
            proxy_redirect     off;
        }

        # ---- Proxy /cloud and /cloud/* to the cloud app ----
        location /cloud {
            proxy_pass         http://cloud:3006;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade $http_upgrade;
            proxy_set_header   Connection "upgrade";
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto $scheme;
            proxy_set_header   X-Forwarded-Host $host;
            proxy_redirect     off;
        }

        # ---- Proxy /bloom and /bloom/* to the bloom app ----
        location /bloom {
            proxy_pass         http://bloom:3005;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade $http_upgrade;
            proxy_set_header   Connection "upgrade";
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto $scheme;
            proxy_set_header   X-Forwarded-Host $host;
            proxy_redirect     off;
        }

        # ---- Everything else goes to the "book" app (docs.medusajs.com) ----
        location / {
            proxy_pass         http://book:3001;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade $http_upgrade;
            proxy_set_header   Connection "upgrade";
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto $scheme;
            proxy_set_header   X-Forwarded-Host $host;
            proxy_redirect     off;
        }
    }
}
```

### Step 4: Create the docker-compose.yml

**Create file:** `/home/damar/projects/medusa/www/docker-compose.yml`

```yaml
version: "3.8"

services:
  # ---- Nginx reverse proxy (the single entry point) ----
  nginx:
    image: nginx:alpine
    container_name: docs-nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - api-reference
      - book
      - ui
      - resources
      - user-guide
      - bloom
      - cloud
    networks:
      - docs-network

  # ---- api-reference app (port 3000, basePath /api) ----
  api-reference:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        APP_NAME: api-reference
        PORT: "3000"
    container_name: docs-api-reference
    expose:
      - "3000"
    networks:
      - docs-network
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  # ---- book app (port 3001, no basePath) ----
  book:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        APP_NAME: book
        PORT: "3001"
    container_name: docs-book
    expose:
      - "3001"
    networks:
      - docs-network
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  # ---- ui app (port 3002, basePath /ui) ----
  ui:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        APP_NAME: ui
        PORT: "3002"
    container_name: docs-ui
    expose:
      - "3002"
    networks:
      - docs-network
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  # ---- resources app (port 3003, basePath /resources) ----
  resources:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        APP_NAME: resources
        PORT: "3003"
    container_name: docs-resources
    expose:
      - "3003"
    networks:
      - docs-network
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  # ---- user-guide app (port 3004, basePath /user-guide) ----
  user-guide:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        APP_NAME: user-guide
        PORT: "3004"
    container_name: docs-user-guide
    expose:
      - "3004"
    networks:
      - docs-network
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  # ---- bloom app (port 3005, basePath /bloom) ----
  bloom:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        APP_NAME: bloom
        PORT: "3005"
    container_name: docs-bloom
    expose:
      - "3005"
    networks:
      - docs-network
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  # ---- cloud app (port 3006, basePath /cloud) ----
  cloud:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        APP_NAME: cloud
        PORT: "3006"
    container_name: docs-cloud
    expose:
      - "3006"
    networks:
      - docs-network
    environment:
      - NODE_ENV=production
    restart: unless-stopped

networks:
  docs-network:
    driver: bridge
```

### Step 5: Build and start everything

Run these commands from the `www/` directory:

```bash
# 1. Build all 7 app images + nginx (this may take 10-20 minutes on first run)
docker compose build

# 2. Start all containers in the background
docker compose up -d

# 3. Check that all 8 containers are running (you should see 8 rows with "Up")
docker compose ps
```

### Step 6: Verify it works

Open these URLs in your browser:

| URL | Expected to see |
|---|---|
| `http://localhost/` | The main docs site (book app) |
| `http://localhost/api` | The API reference |
| `http://localhost/resources` | The resources/commerce modules |
| `http://localhost/ui` | The UI component library docs |
| `http://localhost/user-guide` | The user guide |
| `http://localhost/bloom` | The Bloom landing page |
| `http://localhost/cloud` | The Medusa Cloud docs |

### Step 7: Useful commands for later

```bash
# Stop all containers
docker compose down

# Stop and also delete all built images (clean start)
docker compose down --rmi all

# Rebuild only one app (e.g., if you changed book's code)
docker compose build book
docker compose up -d book

# View logs of all containers
docker compose logs -f

# View logs of one container only
docker compose logs -f book

# Restart all containers
docker compose restart
```

---

## 5. Important Notes

### The .env BASE_URL change explained

Every `NEXT_PUBLIC_BASE_URL` was previously set to `http://10.10.0.3:PORT`.
After this plan, each one becomes `http://localhost:PORT`.

- `10.10.0.3` was a LAN IP. Inside Docker containers, services cannot reach
  each other via that IP.
- `localhost` is correct inside each container because the app still runs on
  `localhost` within its own container.
- The nginx reverse proxy handles all external routing, so you never need to
  type port numbers in your browser.

### No port conflicts

In the original monorepo, `ui`, `cloud`, and `bloom` all shared port `3005` in
their `dev:monorepo` scripts. This docker-compose setup gives each app its own
unique port:

- `bloom` -> `3005`
- `cloud` -> `3006` (matches what its `.env` BASE_URL always expected)

### Why the build is slow on first run

The Dockerfile copies the entire `www/` workspace and runs `yarn install` +
`yarn build:packages` (internal shared packages) + `yarn workspace <app> build`
for each app. Docker builds each service's image independently, so the internal
packages get rebuilt 7 times. This is intentional to keep the setup simple.

### .env files are committed

All 7 `.env` files are tracked by git (they contain no secrets -- only local
development URLs). After this change, your local `.env` files will show up as
modified. This is expected and safe to commit.

---

## 6. Troubleshooting

### "Port 80 is already in use"

Something else on your machine is using port 80. Change the nginx port mapping
in `docker-compose.yml` from `"80:80"` to `"8080:80"`, then access at
`http://localhost:8080`.

### "Cannot find module" or build errors

The internal shared packages (`packages/docs-ui`, `packages/remark-rehype-plugins`,
etc.) may not have built correctly. Run these locally first:

```bash
yarn install
yarn build:packages
```

Then run `docker compose build --no-cache` to force a clean rebuild.

### "502 Bad Gateway" from nginx

This means nginx cannot reach one of the Next.js containers. Check:

```bash
docker compose ps       # Are all 7 app containers "Up"?
docker compose logs book  # Does the book app show "Ready on port 3001"?
```

### One app starts but shows a blank page

Check that the app's `NEXT_PUBLIC_BASE_PATH` matches the nginx location block.
For example, the `api-reference` app has `NEXT_PUBLIC_BASE_PATH=/api` and
nginx sends `/api` requests to it. If these don't match, Next.js won't know
where its assets are.
