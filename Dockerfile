# --- Build Stage ---
FROM node:22-alpine AS builder
WORKDIR /usr/src/app

# Install dependencies first to leverage layer caching
COPY package*.json ./
RUN npm ci

# Copy source and compile
COPY . .
RUN npm run build && npm run build:server

RUN npm prune --production

# --- Production Stage ---
FROM node:22-alpine AS runner
WORKDIR /usr/src/app

ENV NODE_ENV=production
ENV PORT=8080
ENV HOSTNAME=0.0.0.0
# Force WebSockets to process backpressure correctly via standard memory limits
ENV NODE_OPTIONS="--max-old-space-size=2048"

# Install dumb-init to properly forward SIGTERM signals to WebSocket pools
RUN apk add --no-cache dumb-init

# Copy runtime assets from builder
COPY --chown=node:node --from=builder /usr/src/app/node_modules ./node_modules
COPY --chown=node:node --from=builder /usr/src/app/dist ./dist
COPY --chown=node:node --from=builder /usr/src/app/.next ./.next
COPY --chown=node:node --from=builder /usr/src/app/public ./public
COPY --chown=node:node --from=builder /usr/src/app/next.config.ts ./next.config.ts
COPY --chown=node:node --from=builder /usr/src/app/package.json ./package.json

# Enforce non-root execution privilege
USER node

EXPOSE 8080

# dumb-init prevents zombie processes and handles graceful socket drops on container stop
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "dist/main.js"]
