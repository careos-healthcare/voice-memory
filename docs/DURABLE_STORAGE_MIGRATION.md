# Durable storage migration

ArchiveMe stores **auth codes**, **sessions**, and **encrypted sync blobs** in Postgres when `DATABASE_URL` is set. Without it, production falls back to **ephemeral in-memory** storage (single warm serverless instance only). Local development without `DATABASE_URL` uses `.data/` on disk.

## Implemented (Postgres via `DATABASE_URL`)

| Data | Table | Notes |
| --- | --- | --- |
| Email login codes | `auth_codes` | Hashed (`code_hash`), 10-minute TTL, single-use |
| Sessions | `sessions` | `token_hash` + `user_id` + `email`; survives cold starts |
| Encrypted sync blobs | `sync_blobs` | JSONB envelope (`ciphertext`, `iv`, `version` only) |

### Code layout

- `lib/server/db.ts` — pool, idempotent schema init from `docs/sql/001_auth_sync_schema.sql`
- `lib/server/auth-store-postgres.ts` — codes + sessions
- `lib/server/sync-store-postgres.ts` — encrypted blob upsert/pull/manifest
- `lib/server/auth-store.ts` / `sync-store.ts` — route to Postgres or dev fallback

### Apply schema

**Option A — automatic:** tables are created on first DB access via `ensureDatabaseSchema()`.

**Option B — manual:**

```bash
psql "$DATABASE_URL" -f docs/sql/001_auth_sync_schema.sql
```

## Storage modes

| Environment | `DATABASE_URL` | Auth | Sync |
| --- | --- | --- | --- |
| Production | set | Postgres | Postgres |
| Production | unset | In-memory | In-memory |
| Development | set | Postgres | Postgres |
| Development | unset | `.data/auth/` | `.data/sync/` |

Production **never** writes auth or sync JSON to the Vercel filesystem.

## Plaintext rejection

Sync push validates encrypted envelopes in API routes and in `sync-store-postgres.ts`. Fields like `transcript`, `reflection`, `audio`, and `entries` are rejected server-side.

## Future: object storage for large audio

Postgres holds encrypted JSON blobs (e.g. `archive-core`). Heavy encrypted audio backups may move to Vercel Blob / S3 in a later phase while metadata stays in `sync_blobs`.

## Success criteria

- [ ] OTP works for arbitrary emails (verified Resend domain)
- [ ] Auth code survives 60s+ and verifies on a second serverless invocation
- [ ] Push on browser A → pull on browser B returns same ciphertext
- [ ] Sign-out revokes the Postgres session row
- [ ] No plaintext archive fields in sync payloads

## Related docs

- [PRODUCTION_DEPLOY.md](./PRODUCTION_DEPLOY.md) — set `DATABASE_URL` on Vercel before tester onboarding
- [DEPLOY_READINESS_REPORT.md](./DEPLOY_READINESS_REPORT.md) — env checklist
