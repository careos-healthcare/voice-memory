# Deploy readiness report

Generated for VoiceMemory production deployment prep.

## Repo state

| Check | Status |
| --- | --- |
| Branch | `main` |
| Working tree | Clean before deploy-prep commit |
| Latest feature commit | `Add silence intelligence` |
| Validate + build | Run `npm run validate && npm run build` before deploy |

## Environment variable checklist

| Variable | Required | Purpose |
| --- | --- | --- |
| `AUTH_SECRET` | **Yes** (production) | Signs session cookies; app throws at runtime if missing |
| `NEXT_PUBLIC_APP_URL` | Recommended | Production URL for readiness checks and absolute links |
| `OPENAI_API_KEY` | **Yes** for recording flow | Powers `/api/transcribe` and `/api/analyze` |
| `VOICEMEMORY_ENABLE_ATMOSPHERE_API` | No | Set `true` only with OpenAI key to enable DALL-E atmosphere |
| `DEBUG_ACCESS_TOKEN` | No | When set, allows `/debug/*` in production via `?debug_token=` |
| `SYNC_DATA_DIR` | No | Override for encrypted sync + auth JSON store |

## Production hardening audit

### Passed

- **Secrets not committed** — `.env.local` is gitignored; only `.env.example` is tracked
- **Sync endpoints** — `/api/sync/push` rejects non-encrypted blobs; requires session; validates `ciphertext`, `iv`, `version`
- **Sync pull/manifest** — session-gated; returns encrypted envelopes only
- **Atmosphere API** — opt-in via `VOICEMEMORY_ENABLE_ATMOSPHERE_API`; returns `{ source: "fallback" }` when disabled or on failure; client uses local canvas gradients
- **Storage fallback** — `safeSetJson` verify-then-swap with backup key; `safeGetJson` restores from backup on parse failure
- **AUTH_SECRET guard** — `lib/server/auth-crypto.ts` throws in production when unset
- **Debug routes** — `middleware.ts` redirects `/debug/*` to `/` in production unless `DEBUG_ACCESS_TOKEN` matches
- **Session cookies** — `secure: true` in production

### Warnings (document, do not block deploy)

| Risk | Detail | Mitigation |
| --- | --- | --- |
| **Auth email delivery** | `/api/auth/send-code` logs codes in dev only; no SMTP in production yet | Wire email provider before inviting testers; use dev build locally for auth QA |
| **Ephemeral server storage** | Auth + sync JSON live under `.data/` on the server filesystem | Vercel serverless resets between deploys/regions; use persistent volume or external store for multi-device sync |
| **Open API routes** | `/api/transcribe`, `/api/analyze`, `/api/atmosphere` have no session gate | Monitor OpenAI usage; add rate limits or auth before public launch |
| **OPENAI dependency** | Recording fails without key | Set `OPENAI_API_KEY` in Vercel; verify one end-to-end recording post-deploy |

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
6. Account sign-in flow (if SMTP wired)
