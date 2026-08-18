# syntax=docker/dockerfile:1

FROM node:22-alpine AS deps
WORKDIR /usr/src/app

COPY package.json package-lock.json ./
COPY apps/api/package.json ./apps/api/
COPY packages/shared/package.json ./packages/shared/

RUN npm ci --ignore-scripts

FROM node:22-alpine AS builder
WORKDIR /usr/src/app

COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build -w @voice-memory/api

FROM node:22-alpine AS runner
WORKDIR /usr/src/app

ENV NODE_ENV=production
ENV PORT=8080
ENV HOSTNAME=0.0.0.0
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV NEXT_TELEMETRY_DISABLED=1

RUN apk add --no-cache dumb-init \
  && addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 nodejs

COPY --from=builder --chown=nodejs:nodejs /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/apps/api/dist ./apps/api/dist
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/apps/api/.next ./apps/api/.next
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/apps/api/next.config.ts ./apps/api/next.config.ts
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/apps/api/package.json ./apps/api/package.json
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/packages/shared ./packages/shared

WORKDIR /usr/src/app/apps/api
USER nodejs
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8080/api/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "dist/main.js"]
