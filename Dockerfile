FROM docker.io/node:24-slim AS base

ENV NEXT_TELEMETRY_DISABLED=1
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

WORKDIR /app

FROM base AS deps

# Ordered from least likely to most likely to change.
COPY ./.npmrc ./
COPY ./pnpm-workspace.yaml ./
COPY ./package.json ./
COPY ./pnpm-lock.yaml ./
RUN HUSKY=0 pnpm install --frozen-lockfile

FROM base AS builder

COPY --from=deps /app/node_modules ./node_modules
COPY ./.npmrc ./package.json ./pnpm-lock.yaml ./pnpm-workspace.yaml ./

# Ordered from least likely to most likely to change.
COPY \
  ./next.config.mjs \
  ./postcss.config.mjs \
  ./schema.graphql \
  ./tailwind.config.ts \
  ./tsconfig.json \
  ./
COPY ./src ./src

# NEXT_PUBLIC_LOG_LEVEL={info, warn, error}
ARG NEXT_PUBLIC_LOG_LEVEL=info
ENV NEXT_PUBLIC_LOG_LEVEL=${NEXT_PUBLIC_LOG_LEVEL}

ARG NEXT_PUBLIC_INITIAL_CHANNEL_SLUG=default-channel
ENV NEXT_PUBLIC_INITIAL_CHANNEL_SLUG=${NEXT_PUBLIC_INITIAL_CHANNEL_SLUG}

# Run the build
RUN NEXT_OUTPUT=standalone pnpm build

FROM docker.io/node:24-slim AS runner

ENV NODE_ENV=production

RUN groupadd --system --gid 1001 nodejs \
  && useradd --system --uid 1001 --gid nodejs nextjs \
  && mkdir .next \
  && chown nextjs:nodejs .next

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3331
ENV PORT=3331
CMD ["node", "server.js"]
