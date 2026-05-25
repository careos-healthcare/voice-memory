# Durable storage migration plan

VoiceMemory today stores **auth codes** and **encrypted sync blobs** on the Vercel server filesystem (`.data/`), which is **ephemeral** across regions, cold starts, and deploys. Encrypted backup works on a single warm instance; **cross-device sync and auth codes are not production-reliable** until storage is externalized.

Auth email (Resend) is independent of this; fix email first, then migrate storage.

## What must become durable

| Data | Today | Requirement |
| --- | --- | --- |
| Email login codes | In-memory or `.data/` auth store | TTL rows, single-use, survives cold start |
| Sessions | Cookie + server session store | Same store as codes or JWT with server secret |
| Encrypted sync blobs | `.data/sync/{userId}/blobs.json` | Per-user blob upsert, pull, manifest |
| (Future) Audit / rate limits | None | Optional |

Client-side archive stays in **localStorage + IndexedDB**; server never holds plaintext.

## Option A — Postgres (Neon / Supabase / RDS)

**Best fit:** minimal schema, full control, matches existing `DATABASE_URL` notes in deploy docs.

**Schema sketch:**

- `auth_codes(email, code_hash, expires_at, created_at)`
- `sessions(id, user_id, email, expires_at)`
- `sync_blobs(user_id, blob_id, type, ciphertext, iv, version, updated_at, byte_length)`
- `sync_manifest` derived from `sync_blobs` or `users.updated_at`

**Pros:** Simple SQL, portable, works with Vercel serverless via connection pooler (Neon serverless driver, Supabase pooler, Prisma + `pg`).

**Cons:** You operate migrations and backups; large audio blobs should not live in Postgres rows (keep audio as separate blob objects — see Option C hybrid).

**Effort:** Medium — replace `lib/server/auth-store.ts`, `lib/server/sync-store.ts`, add migration SQL.

## Option B — Supabase

**Best fit:** fastest path if you want dashboard auth, RLS, and hosted Postgres together.

**Pros:** Managed Postgres, optional Supabase Auth later, storage bucket for large encrypted audio blobs, good DX.

**Cons:** Vendor surface area; still need custom tables for encrypted blob metadata if not using Storage for everything.

**Effort:** Medium — same as Postgres plus Supabase client; map existing session cookie flow or migrate to Supabase Auth in a later phase.

## Option C — Neon Postgres + object storage (recommended long-term)

**Best fit:** production sync with **many audio backups**.

- **Neon** (or any Postgres): auth codes, sessions, blob **metadata** and small JSON ciphertext (archive-core)
- **Vercel Blob / S3 / Supabase Storage**: `audio-{entryId}` encrypted payloads

**Pros:** Scales audio size, keeps DB small, clear separation.

**Cons:** Two systems to configure and monitor.

**Effort:** Higher initial, best operational story.

## Recommended sequence

1. **Resend verified domain** — all users can receive OTP (current blocker for real testers).
2. **Phase 1 — Auth only on Postgres** (`DATABASE_URL`): codes + sessions durable; keep sync on filesystem temporarily.
3. **Phase 2 — Sync metadata on Postgres**: `archive-core` and manifest in SQL.
4. **Phase 3 — Audio to object storage** (if blob size or count grows).
5. Load-test: sign-in on device A, backup, sign-in on device B, pull + restore preview.

## Code touchpoints (no behavior change until implemented)

- `lib/server/auth-storage.ts` / `auth-store.ts`
- `lib/server/sync-store.ts`
- `app/api/auth/*`, `app/api/sync/*`
- Env: `DATABASE_URL` (already documented); optional `BLOB_READ_WRITE_TOKEN` or S3 vars for phase 3

## Success criteria

- [ ] OTP works for arbitrary emails (verified domain)
- [ ] Auth code survives 60s+ and verify on second serverless invocation
- [ ] Push on browser A → pull on browser B returns same `archive-core` ciphertext
- [ ] No `JSON.parse` / empty sync responses (client hardening already shipped)
- [ ] Encrypted backup completes without `AUTH_RESEND_REJECTED` or corrupt-remote loops

## Decision guide

| Priority | Choose |
| --- | --- |
| Ship auth reliability this week | Neon or Supabase **Postgres only** (Phase 1) |
| Small team, one vendor | Supabase |
| Max control, existing SQL comfort | Neon + Prisma/Drizzle |
| Heavy audio backup | Neon + Vercel Blob / S3 |

Do not block Resend domain setup on storage migration; they are parallel tracks.
