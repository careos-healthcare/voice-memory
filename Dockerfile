# --- Build Stage ---
FROM node:22-alpine AS builder
WORKDIR /usr/src/app

# Install dependencies first to leverage layer caching
COPY package*.json ./
RUN npm ci

# Copy source and compile the API-only Next.js artifact plus custom WebSocket server.
COPY . .
RUN npm run build:backend

RUN npm prune --production

# --- Production Stage ---
FROM node:22-alpine AS runner
WORKDIR /usr/src/app

ENV NODE_ENV=production
ENV PORT=8080
ENV HOSTNAME=0.0.0.0
ENV VOICEMEMORY_UNIT_ECONOMICS_PRICING_CATALOG_PATH=".backend-release/config/unit-economics/pricing-catalog.v1.json"
# Force WebSockets to process backpressure correctly via standard memory limits
ENV NODE_OPTIONS="--max-old-space-size=2048"

# Install dumb-init to properly forward SIGTERM signals to WebSocket pools
RUN apk add --no-cache dumb-init

# Copy runtime assets from builder
COPY --chown=node:node --from=builder /usr/src/app/node_modules ./node_modules
COPY --chown=node:node --from=builder /usr/src/app/dist ./dist
COPY --chown=node:node --from=builder /usr/src/app/.backend-release ./.backend-release
COPY --chown=node:node --from=builder /usr/src/app/package.json ./package.json

# Enforce non-root execution privilege
USER node

EXPOSE 8080

# dumb-init prevents zombie processes and handles graceful socket drops on container stop
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "dist/main.js"]
