# Fact ledger embedding migration — forensic audit

**Audit date:** 2026-08-08  
**Subject:** `docs/sql/005_fact_ledger_gemini_768.sql` (OpenAI 1536-d → Gemini 768-d)  
**Question:** Did this migration truncate live production user data, or only pre-launch / dev data?

---

## Executive summary

**There is no evidence that `005_fact_ledger_gemini_768.sql` was ever committed, merged, or executed against a production database with live users.** The file exists only as an **untracked local artifact** in the working tree. The server-side Postgres `fact_ledger` pgvector stack itself is **not present on `origin/main`** at the time of this audit.

**Conclusion (C):** Any `TRUNCATE fact_ledger` defined in this script would affect **only databases where an operator manually ran the file**—most likely local/dev Postgres instances during pre-launch Evidence Method development. **It did not touch real production users via an automated deploy path.**

---

## 1. Git history check

| Field | Finding |
| --- | --- |
| **Commit SHA** | *None — file is untracked* |
| **Commit date** | *N/A* |
| **Merge date** | *N/A — never merged to `main`* |
| **Author (git)** | *N/A* |

### Commands run

```bash
git log --follow -- docs/sql/005_fact_ledger_gemini_768.sql   # empty
git status -- docs/sql/005_fact_ledger_gemini_768.sql           # untracked
git ls-tree -r origin/main docs/sql/                          # 001, 002, 003 only
```

### Filesystem metadata (local working copy)

| File | Created (birth) | Last modified |
| --- | --- | --- |
| `docs/sql/005_fact_ledger_gemini_768.sql` | 2026-08-08 ~19:00 BST | 2026-08-08 ~22:15 BST |
| `docs/sql/004_fact_ledger_pgvector.sql` | 2026-08-08 ~18:23 BST | 2026-08-08 ~22:15 BST |

Both `004` and `005` are **untracked** alongside other Evidence Method server files (`packages/shared/lib/server/evidence-schema.ts`, `packages/shared/types/insights.ts`, `apps/api/lib/ledger/*`, etc.).

### Session provenance (non-git)

Cursor agent transcript (`624147d6-8712-4311-85f3-2bac9d33c750`) records:

1. **~2026-08-08 (evening):** `005` was first written when `FACT_LEDGER_EMBEDDING_DIMENSIONS` changed from **1536** (OpenAI) to **768** (Gemini). The initial version contained **unconditional** `TRUNCATE fact_ledger` before `ALTER COLUMN embedding TYPE vector(768)`.
2. **~2026-08-08 21:33 UTC+1:** User-requested hardening replaced the bare script with a guarded `DO` block requiring `SET voice_memory.confirm_fact_ledger_reembed = 'yes'` when rows exist.

**There is no git author or merge record** because the work was never committed.

### Related: what *is* on `origin/main`

- `docs/sql/001_auth_sync_schema.sql`, `002_grade_a_schema.sql`, `003_mobile_push_devices.sql` — tracked
- **No** `004_fact_ledger_pgvector.sql` or `005_fact_ledger_gemini_768.sql`
- **No** `fact_ledger` table in `lib/server/db.ts` on `origin/main` (no pgvector ledger DDL in shipped server schema)
- Mobile **local** fact-ledger UI/store exists under `apps/voicememory_mobile/lib/features/fact_ledger/` (client-side), separate from Postgres ledger migration scope

---

## 2. Backfill / recovery script search

Searched the full repository for: `reembed`, `backfill`, `reingest_transcripts`, `recover_ledger`, `005_fact_ledger`, `confirm_fact_ledger_reembed`.

### Dedicated recovery scripts

| Pattern | Result |
| --- | --- |
| `reembed` / `re-embed` | Only in `005` header comments and `docs/ENGINEERING_CHARTER.md` (operational instructions) |
| `recover_ledger` | **No matches** |
| `reingest_transcripts` | **No matches** |
| `scripts/*reembed*` | **No files** |

**No purpose-built “recover from 005 truncation” script exists.** That strongly suggests no production incident required a historical re-processing pipeline to be checked in.

### Related (but not migration-recovery) ingestion paths

| Path | Purpose | Recovery indicator? |
| --- | --- | --- |
| `apps/api/src/services/ledger/bulk_ingest.ts` | Batch embed + insert for cold-start / backlog import | **No** — product feature (`/api/ledger/bulk-import`), preserves `created_at`; not named or documented as post-005 recovery |
| `apps/api/src/services/ledger/ingest.ts` | Single-chunk ingest on save | Normal write path |
| `apps/api/src/routes/ledger/bulk_import.ts` | HTTP handler for bulk import + optional cold-start insight | Onboarding / import wedge |
| `apps/api/src/__tests__/genericness_qa.test.ts` | `DELETE FROM fact_ledger WHERE user_id = $1` in test setup | **Test-only** seed/teardown |

Unrelated “backfill” hits (`blind-spot-quality-report.ts`, `first-week-funnel.ts`) are analytics/UI state, not ledger embeddings.

---

## 3. Migration execution path (seed vs production runner)

### Not wired to automated migration runners

| Mechanism | Uses `005`? |
| --- | --- |
| **Prisma** | No Prisma directory in repo |
| **Flyway** | No Flyway config |
| **`npm run validate:migrations`** | **No** — validates `AUTH_SYNC_SCHEMA_STATEMENTS` in `packages/shared/lib/server/db.ts` against `migration-manifest.ts` (table/index presence only) |
| **Root `package.json`** | **No** `psql` / `005` references |
| **CI workflows** (`.github/workflows/*.yml`) | **No** reference to `004` or `005` |
| **App cold-start schema init** | `db.ts` merges `EVIDENCE_METHOD_SCHEMA_STATEMENTS` with `CREATE TABLE IF NOT EXISTS fact_ledger (... vector(768) ...)` — **fresh installs get 768-d directly**; does **not** run `005` |

### Intended execution model (manual ops only)

From `005` header and `docs/ENGINEERING_CHARTER.md`:

```bash
psql "$DATABASE_URL" \
  -c "SET voice_memory.confirm_fact_ledger_reembed = 'yes';" \
  -f docs/sql/005_fact_ledger_gemini_768.sql
```

This is **operator-initiated**, not deploy-hook automated.

### Guardrails in current `005` (post-hardening)

1. **Idempotent skip** if `embedding` is already `vector(768)` — preserves rows
2. **Empty table** — migrates without confirmation flag
3. **Non-empty table** — **`RAISE EXCEPTION`** unless `voice_memory.confirm_fact_ledger_reembed = 'yes'`
4. Optional `voice_memory.environment = 'production'` for audit logging only

The **earliest** version of `005` (same day, before hardening) used unconditional `TRUNCATE` with no row-count guard. That version was never committed; any local run between ~19:00–21:33 BST would have been operator/dev-only.

---

## 4. Required answers

### (A) What date was the truncation introduced?

| Event | Date (local) | Notes |
| --- | --- | --- |
| **TRUNCATE logic first authored** | **2026-08-08** (~19:00 BST file birth) | Initial `005` draft in working tree; unconditional `TRUNCATE fact_ledger` |
| **Production guardrails added** | **2026-08-08** (~21:33 UTC+1 per session; ~22:15 BST mtime) | Requires `confirm_fact_ledger_reembed = 'yes'` when rows exist |
| **Git commit / merge** | **Never** | File remains untracked |

### (B) Is there evidence of a transcript backfill / re-ingestion script written to recover from it?

**No dedicated recovery script.**  

The closest capability is **`bulkIngestHistoricalChunks`** (`bulk_ingest.ts` + `/api/ledger/bulk-import`), which re-embeds and inserts historical transcript chunks—but it is a **v1 cold-start / backlog import product path**, not a migration-recovery tool, and there is no documentation linking it to `005` fallout.

Absence of `reembed`, `recover_ledger`, or `reingest_transcripts` scripts is consistent with **no production truncation event** that required a checked-in recovery pipeline.

### (C) Conclusion: production users or pre-launch/dev only?

**Pre-launch / dev environment only (with high confidence).**

| Evidence | Weight |
| --- | --- |
| `005` never committed or merged to `main` | Strong |
| Server `fact_ledger` pgvector schema not on `origin/main` | Strong |
| No CI/deploy hook executes `005` | Strong |
| No recovery scripts in repo | Moderate |
| Guardrails block unattended truncate when rows exist | Moderate (protects future ops) |
| Manual `psql` only execution path | Strong |

**Caveat:** If a developer manually ran the **early unconditional** `005` against a shared staging database that contained real beta-user ledger rows, those rows would have been truncated **in that environment only**. There is **no repository or git evidence** of such a run, and no production deploy path would have applied this migration automatically.

---

## 5. Recommendations

1. **Before first production deploy with pgvector ledger:** ship `004`/`005` in git; run `005` only after row-count review; prefer empty-table migrate or fresh `004` install on `vector(768)`.
2. **If migrating an existing 1536-d database:** export `raw_text` + metadata before `TRUNCATE`; use bulk-import to re-embed (document as runbook step, not ad-hoc).
3. **Commit or reject untracked Evidence Method files** so migration provenance is auditable via git going forward.

---

## Appendix — files examined

- `docs/sql/004_fact_ledger_pgvector.sql`
- `docs/sql/005_fact_ledger_gemini_768.sql`
- `packages/shared/lib/server/evidence-schema.ts`
- `packages/shared/lib/server/db.ts`
- `packages/shared/lib/server/migration-manifest.ts`
- `packages/shared/types/insights.ts`
- `scripts/validate-migrations.mjs`
- `apps/api/src/services/ledger/bulk_ingest.ts`
- `apps/api/src/routes/ledger/bulk_import.ts`
- `docs/ENGINEERING_CHARTER.md`
- `origin/main` tree via `git ls-tree` / `git show`
