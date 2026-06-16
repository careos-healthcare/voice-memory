# Deploy readiness report

Generated for ArchiveMe production deployment prep.

## Repo state

| Check | Status |
| --- | --- |
| Branch | `main` |
| Working tree | Run `git status` before deploy |
| Validate + build | Run `npm run validate && npm run build` before deploy |

## Environment variable checklist

| Variable | Required | Purpose |
| --- | --- | --- |
| `AUTH_SECRET` | **Yes** (production) | Signs session cookies; app throws at runtime if missing |
| `DATABASE_URL` | **Yes** (tester onboarding) | Postgres for durable auth codes, sessions, and encrypted sync |
| `NEXT_PUBLIC_APP_URL` | Recommended | Production URL for readiness checks and absolute links |
| `OPENAI_API_KEY` | **Yes** for recording flow | Powers `/api/transcribe` and `/api/analyze` |
| `VOICEMEMORY_ENABLE_ATMOSPHERE_API` | No | Set `true` only with OpenAI key to enable DALL-E atmosphere |
| `DEBUG_ACCESS_TOKEN` | No | When set, allows `/debug/*` in production via `?debug_token=` |
| `RESEND_API_KEY` | **Yes** (production email) | Sends sign-in codes via Resend |
| `EMAIL_FROM` | **Yes** (production email) | Verified sender address in Resend |

## Production hardening audit

### Passed

- **Secrets not committed** — `.env.local` is gitignored; only `.env.example` is tracked
- **Durable storage** — when `DATABASE_URL` is set, auth codes, sessions, and encrypted sync use Postgres (`lib/server/db.ts`, `docs/sql/001_auth_sync_schema.sql`)
- **No production filesystem auth/sync** — Vercel production uses Postgres or in-memory fallback, never `.data/` writes
- **Sync endpoints** — `/api/sync/push` rejects non-encrypted blobs; requires session; validates `ciphertext`, `iv`, `version`
- **Sync pull/manifest** — session-gated; returns encrypted envelopes only
- **Atmosphere API** — opt-in via `VOICEMEMORY_ENABLE_ATMOSPHERE_API`; returns `{ source: "fallback" }` when disabled or on failure
- **Storage fallback** — client `safeSetJson` verify-then-swap with backup key
- **AUTH_SECRET guard** — `lib/server/auth-crypto.ts` throws in production when unset
- **Debug routes** — `middleware.ts` redirects `/debug/*` to `/` in production unless `DEBUG_ACCESS_TOKEN` matches
- **Session cookies** — `secure: true` in production; Postgres session rows when `DATABASE_URL` is set

### Warnings (document, do not block deploy)

| Risk | Detail | Mitigation |
| --- | --- | --- |
| **Auth email delivery** | Requires `RESEND_API_KEY` and `EMAIL_FROM` in production | Verify domain/sender in Resend before inviting testers |
| **Ephemeral fallback** | Without `DATABASE_URL`, production uses in-memory auth + sync per instance | Set `DATABASE_URL` before multi-device tester onboarding |
| **Open API routes** | `/api/transcribe`, `/api/analyze`, `/api/atmosphere` have no session gate | Monitor OpenAI usage; add rate limits or auth before public launch |
| **OPENAI dependency** | Recording fails without key | Set `OPENAI_API_KEY` in Vercel; verify one end-to-end recording post-deploy |

## Postgres setup (before testers)

1. Create a Postgres database (Neon, Supabase, RDS, etc.).
2. Set `DATABASE_URL` in Vercel project environment variables.
3. Apply schema: `psql "$DATABASE_URL" -f docs/sql/001_auth_sync_schema.sql` (or rely on auto-init).
4. Smoke test: send code → verify on a cold instance → push encrypted backup → pull on second browser.

See [DURABLE_STORAGE_MIGRATION.md](./DURABLE_STORAGE_MIGRATION.md).

## Vercel configuration

- `vercel.json` — Next.js framework, `noindex` headers on `/debug/*`
- Build command (recommended): `npm run build` (run `npm run validate` in CI or pre-deploy locally)
- Install command: default `npm install`

## Pre-deploy commands

```bash
npm run validate
npm run build
git push origin main
npx vercel --prod   # or npx vercel on first link
```

## Post-deploy smoke (see `POST_DEPLOY_QA.md`)

1. Homepage loads, recorder visible
2. One recording → transcript → entry page
3. Export JSON downloads
4. Settings → silence intelligence toggle
5. Atmosphere on entry → fallback gradient without API flag
6. Account sign-in → encrypted backup push/pull across two browsers (with `DATABASE_URL`)
