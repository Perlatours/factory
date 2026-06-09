# Panel factory — Next.js 16 (output: standalone). Build multi-stage con pnpm.
FROM node:22-bookworm-slim AS base
RUN corepack enable
WORKDIR /app

# 1) deps (cacheable)
FROM base AS deps
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# 2) build
FROM base AS build
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm build

# 3) runtime mínimo (solo lo que server.js necesita)
FROM base AS run
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
COPY --from=build /app/public ./public
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
EXPOSE 3000
CMD ["node", "server.js"]
