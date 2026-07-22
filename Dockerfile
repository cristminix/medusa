# syntax=docker/dockerfile:1

# ---------- deps: manifests only, for a cacheable install layer ----------
FROM node:20-alpine AS deps

WORKDIR /app
RUN corepack enable && corepack prepare yarn@3.2.1 --activate

# Yarn 3 defaults to PnP; the Next.js builds here expect node_modules
ENV YARN_NODE_LINKER=node-modules

COPY www/package.json www/yarn.lock www/.yarnrc.yml ./

# Every workspace manifest must be present for Yarn to resolve the tree.
COPY www/apps/api-reference/package.json        apps/api-reference/
COPY www/apps/bloom/package.json                apps/bloom/
COPY www/apps/book/package.json                 apps/book/
COPY www/apps/cloud/package.json                apps/cloud/
COPY www/apps/resources/package.json            apps/resources/
COPY www/apps/ui/package.json                   apps/ui/
COPY www/apps/user-guide/package.json           apps/user-guide/
COPY www/packages/build-scripts/package.json    packages/build-scripts/
COPY www/packages/docs-ui/package.json          packages/docs-ui/
COPY www/packages/docs-utils/package.json       packages/docs-utils/
COPY www/packages/remark-rehype-plugins/package.json packages/remark-rehype-plugins/
COPY www/packages/tags/package.json             packages/tags/
COPY www/packages/tailwind/package.json         packages/tailwind/
COPY www/packages/tsconfig/package.json         packages/tsconfig/
COPY www/packages/types/package.json            packages/types/

RUN --mount=type=cache,target=/root/.yarn/berry/cache \
    yarn install --immutable


# ---------- builder: compile shared packages, then all Next apps ----------
FROM node:20-alpine AS builder

WORKDIR /app
RUN corepack enable && corepack prepare yarn@3.2.1 --activate
RUN apk add --no-cache git

ENV YARN_NODE_LINKER=node-modules
ENV NODE_ENV=production
# Seven Next builds in one pass will OOM on the default heap
ENV NODE_OPTIONS=--max-old-space-size=6144

# The whole install tree, not just the root node_modules: Yarn's node-modules
# linker leaves un-hoistable versions in per-workspace node_modules dirs
# (e.g. packages/types/node_modules/typescript), and those are needed to build.
COPY --from=deps /app ./
COPY www .

# Belt-and-braces: if a local PnP artifact slips past .dockerignore it would
# hijack Node's ESM loader and fail the build with ERR_LOADER_CHAIN_INCOMPLETE.
RUN rm -f .pnp.cjs .pnp.loader.mjs .yarn/install-state.gz

# build-scripts/generate-edited-dates shells out to git. The real .git is not in
# the context (and would not help: its paths are rooted at the monorepo, not at
# www). A throwaway repo rooted here makes ls-files/diff report a clean tree, so
# the script early-returns and the committed generated/edit-dates.mjs stands.
RUN printf 'node_modules/\n.next/\n.turbo/\ndist/\n' > .git-exclude \
 && git init -q -b main . \
 && mv .git-exclude .git/info/exclude \
 && git add -A \
 && git -c user.email=build@localhost -c user.name=docker commit -qm "build snapshot"

# Shared packages first, then the apps (turbo's ^build dependsOn handles ordering)
RUN yarn build:packages && yarn build


# ---------- runtime ----------
FROM node:20-alpine AS runner

WORKDIR /app
RUN apk add --no-cache nginx

ENV NODE_ENV=production

COPY --from=builder /app ./
COPY nginx.conf /etc/nginx/nginx.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
