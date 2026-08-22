# ArchiveMe — Turborepo monorepo

**ArchiveMe's canonical consumer product is the Flutter mobile app** at
[`apps/mobile`](./apps/mobile). This repository is a Turborepo workspace:

| Workspace | Path | Purpose |
|-----------|------|---------|
| **Web** | [`apps/web`](./apps/web) | Next.js frontend (pages, components, marketing) |
| **API** | [`apps/api`](./apps/api) | Next.js API routes + custom Node server |
| **Mobile** | [`apps/mobile`](./apps/mobile) | Flutter consumer app |
| **Shared** | [`packages/shared`](./packages/shared) | Shared TypeScript libraries and types |

There is one product promise, and it should read the same whether you're in
the app, on a marketing page, or in privacy copy:

> **Record a real moment, preserve the evidence, and safely see what changed
> over time.**

If you're looking for the consumer product itself — recording, the Archive,
proof/evidence display, correction controls, subscription — that all lives in
the Flutter app under `apps/mobile`. See its
[README](./apps/mobile/README.md) for how to run it.

## Stack

- Turborepo + npm workspaces
- Next.js 15 (App Router) — web + API apps
- TypeScript — `packages/shared`
- Flutter — `apps/mobile`

## Engineering standards

Contributors and reviewers should read **[`docs/ENGINEERING_CHARTER.md`](./docs/ENGINEERING_CHARTER.md)** before making architectural or product-surface changes. It codifies the baseline for automated quality gates (~230 validators), the Evidence Method (pgvector fact ledger), internal validation tooling, and the pragmatic stack choices (Next.js 15, PostgreSQL/pgvector, Redis, Resend, pino).

## Getting started

```bash
npm install

# Run all dev servers (web on :3000, API on its configured port)
npm run dev

# Or individually
npm run dev:web
npm run dev:api

# Typecheck, lint, and build across workspaces
npm run typecheck
npm run lint
npm run build
```

## Docker production stack

Unified deployment via Docker Compose (web + API + Redis + Nginx gateway):

```bash
cp .env.example .env
docker compose up --build -d
```

- **Web** (`apps/web`) — Next.js standalone frontend on `:3000` (internal)
- **API** (`apps/api`) — Node.js REST + Gemini WebSockets on `:8080` (internal)
- **Gateway** — Nginx on `:80` / `:443` routes `/api/*` → API, everything else → web


## Mobile app

```bash
cd apps/mobile
flutter pub get
flutter run
```
