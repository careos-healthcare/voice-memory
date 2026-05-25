# Production deploy — VoiceMemory

Deploy VoiceMemory to Vercel from the `main` branch after local validation passes.

## Prerequisites

- Node.js 20+
- Vercel CLI (`npx vercel`)
- GitHub remote with push access
- OpenAI API key (transcription + analysis)
- Strong random `AUTH_SECRET` (32+ bytes)

## 1. Pre-deploy validation

```bash
git status          # working tree clean
git branch          # on main
git log --oneline -5

npm run validate
npm run build
```

Fix any validator or TypeScript errors before continuing.

## 2. Environment setup (Vercel dashboard)

Project → Settings → Environment Variables → Production:

| Variable | Value | Notes |
| --- | --- | --- |
| `AUTH_SECRET` | Random secret | Required |
| `DATABASE_URL` | Postgres connection string | Required before tester onboarding — durable auth + sync |
| `NEXT_PUBLIC_APP_URL` | `https://your-app.vercel.app` | Set after first deploy if URL unknown |
| `OPENAI_API_KEY` | `sk-…` | Required for recording |
| `VOICEMEMORY_ENABLE_ATMOSPHERE_API` | `false` | Set `true` only to enable DALL-E atmosphere |
| `DEBUG_ACCESS_TOKEN` | Optional random string | Enables `/debug/*` in production |
| `RESEND_API_KEY` | Resend sending key | Required for production OTP email |
| `EMAIL_FROM` | `VoiceMemory <noreply@your-verified-domain>` | After domain verify — see [RESEND_DOMAIN_AUTH.md](./RESEND_DOMAIN_AUTH.md) |

Copy from [`.env.example`](../.env.example). Never commit real secrets.

**Auth email:** Sandbox `onboarding@resend.dev` only delivers to the Resend account owner. For all testers, verify a domain in Resend and update `EMAIL_FROM` (runbook above).

## 3. Push to GitHub

```bash
git push origin main
```

## 4. Deploy to Vercel

**First time (link project):**

```bash
npx vercel
```

Follow prompts: link to GitHub repo, confirm framework Next.js, use default build settings.

**Production deploy:**

```bash
npx vercel --prod
```

Or enable automatic deploys from `main` in the Vercel dashboard.

## 5. Post-deploy URL

After deploy, set `NEXT_PUBLIC_APP_URL` to the production URL and redeploy once.

## 6. Functional tests (before inviting testers)

Run these on the production URL. Details in [POST_DEPLOY_QA.md](./POST_DEPLOY_QA.md).

### Restore test

1. Settings → Export all → save JSON
2. Settings → Delete all local data (confirm phrase)
3. Settings → Import / restore from export
4. Confirm entries, transcripts, and bookmarks return

### Sync test

1. Sign in on two browsers (requires auth email delivery — see risks below)
2. Record on device A → sync push
3. Pull on device B → encrypted blobs merge locally
4. Confirm no plaintext on server (only ciphertext in network tab)

### Export / import test

1. Export JSON from Settings
2. Verify bundle includes entries, settings flags, photo metadata
3. Import on clean profile → archive intact

### Mobile test

1. iOS Safari — record, playback, entry view, scroll
2. Android Chrome — same flow
3. Confirm microphone permission prompt on first record

### Silence intelligence test

1. Settings → confirm **Silence intelligence on**
2. Ignore several memory callbacks (open app without engaging)
3. Confirm fewer notes / optional line: “Nothing needs to surface right now.”
4. Toggle off → callbacks resume
5. Debug (if token set): `/debug/silence-intelligence?debug_token=…`

### Atmosphere fallback test

1. Open an entry → **Create quiet atmosphere** (with `VOICEMEMORY_ENABLE_ATMOSPHERE_API=false`)
2. Confirm local abstract gradient saves (no API error surfaced to user)
3. Optional: enable API flag + OpenAI key → confirm image path works

### Backup integrity test

1. Settings → Export
2. Open JSON — no raw audio blobs required; entries + metadata present
3. Run restore; compare entry count before/after
4. Debug (if token set): `/debug/storage-health` — photo/audio counts consistent

## 7. Known deployment risks

See [DEPLOY_READINESS_REPORT.md](./DEPLOY_READINESS_REPORT.md):

- **Auth codes** — production sends via Resend; set `RESEND_API_KEY` and verified-domain `EMAIL_FROM` ([RESEND_DOMAIN_AUTH.md](./RESEND_DOMAIN_AUTH.md))
- **Durable auth + sync** — set `DATABASE_URL` (Postgres) before real tester onboarding; without it codes and encrypted blobs live in ephemeral server memory only
- **Schema** — apply `docs/sql/001_auth_sync_schema.sql` or rely on automatic init on first request
- **Open API routes** — transcribe/analyze unauthenticated; monitor usage

## 8. Rollback

Vercel dashboard → Deployments → previous deployment → **Promote to Production**.

Local rollback:

```bash
git revert HEAD
git push origin main
```

## 9. Tester handoff

Share production URL and [POST_DEPLOY_QA.md](./POST_DEPLOY_QA.md) checklist. Recommended flow:

1. Record one reflection (60s)
2. Revisit entry next day
3. Export backup
4. Try bookmark + roundup if entries exist
5. Report issues via contact page
