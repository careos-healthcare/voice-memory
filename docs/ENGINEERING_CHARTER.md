# ArchiveMe Engineering Charter

Permanent baseline for code quality, architectural integrity, and how this repository is meant to be extended. When a design choice conflicts with this charter, resolve the conflict explicitly in the PRD or update the charter—do not drift silently.

**Audience:** contributors, reviewers, and future maintainers.  
**Companion index:** [`docs/history/README.md`](history/README.md) (historical audits; not current spec).

---

## 1. Rigorous Pre-Launch Engineering & Automated Quality Gates

ArchiveMe treats product restraint, safety, and copy integrity as **compile-time and CI-time constraints**, not post-launch polish. The monorepo ships roughly **230 automated quality gates**—226 `validate:*` npm scripts backed by **200+** `scripts/validate-*.mjs` checkers, plus **25** `scripts/run-*-tests.mjs` harnesses for focused regression suites.

### What this enforces

- **Product restraint** — copy, UX pressure, monetization framing, and archive permanence rules must not regress (`npm run validate:restraint` consolidates 18 former single-purpose scripts).
- **Blind-spot & resurfacing quality** — insight surfacing loops, open-loop fatigue, and variety gates (`validate:blind-spot`, `validate:resurfacing`).
- **Design consistency** — archive page grammar, typography/spacing audits, and mobile/web parity (`validate:design-consistency`).
- **Security & production readiness** — auth guards, rate limits, migration safety, billing, and environment validation (included in root `npm run validate`).
- **Clinical quarantine** — experimental cognitive/clinical analysis code must never leak to public API surfaces or unsanitized logs.
- **Genericness QA** — insights must be anchored to a specific user's ledger evidence, not interchangeable journal platitudes.

### Implementation map

| Concern | Entry points | Code paths |
| --- | --- | --- |
| Validator catalog | Root `package.json` (`validate:*`), `npm run validate` | [`scripts/`](../scripts/) |
| Unified restraint gate | `npm run validate:restraint` | [`scripts/validate-product-restraint.mjs`](../scripts/validate-product-restraint.mjs) |
| Blind-spot gate | `npm run validate:blind-spot` | [`scripts/validate-blind-spot.mjs`](../scripts/validate-blind-spot.mjs) |
| Resurfacing gate | `npm run validate:resurfacing` | [`scripts/validate-resurfacing.mjs`](../scripts/validate-resurfacing.mjs) |
| Design consistency | `npm run validate:design-consistency` | [`scripts/validate-design-consistency.mjs`](../scripts/validate-design-consistency.mjs), [`packages/shared/lib/design/`](../packages/shared/lib/design/), [`apps/web/components/layout/ArchivePageBlueprint.tsx`](../apps/web/components/layout/ArchivePageBlueprint.tsx) |
| Clinical quarantine | `npm run validate:clinical-quarantine` | [`scripts/validate-clinical-quarantine.mjs`](../scripts/validate-clinical-quarantine.mjs), [`apps/api/src/internal/clinical/`](../apps/api/src/internal/clinical/), [`apps/api/src/internal/clinical/quarantine-audit-tests.ts`](../apps/api/src/internal/clinical/quarantine-audit-tests.ts), [`apps/api/src/internal/clinical/audit-public-surface.ts`](../apps/api/src/internal/clinical/audit-public-surface.ts) |
| Log sanitization (quarantine paths) | (part of clinical-quarantine) | [`apps/api/lib/utils/logger-sanitization-tests.ts`](../apps/api/lib/utils/logger-sanitization-tests.ts), [`packages/shared/lib/server/log-sanitizer.ts`](../packages/shared/lib/server/log-sanitizer.ts) |
| Genericness QA pipeline | `npm run validate:genericness-qa` | [`scripts/validate-genericness-qa.mjs`](../scripts/validate-genericness-qa.mjs), [`apps/api/src/__tests__/genericness_qa.test.ts`](../apps/api/src/__tests__/genericness_qa.test.ts) |
| CI enforcement | GitHub Actions on `main` | [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) (typecheck + genericness QA on API; Flutter analyze/test on mobile) |
| Playwright / E2E | `e2e/*.spec.ts` | [`e2e/`](../e2e/) |

### Operating rules

1. **New user-visible copy or flows** — run targeted validators (`validate:restraint`, domain-specific `validate:*`) before opening a PR.
2. **New public API fields** — must pass clinical quarantine audit; no diagnostic or biomarker vocabulary on public routes.
3. **New insight generation** — must pass genericness QA when `DATABASE_URL` and model keys are available; CI runs this on every backend job.
4. **Do not delete validators** without consolidating coverage into an existing unified gate and updating `package.json`.

---

## 2. Built-In User-Research & Validation Infrastructure

ArchiveMe embeds founder-led research tooling **inside the product shell**, not in external spreadsheets. Validators assert that this infrastructure stays wired; the UI is the instrument.

### What this provides

- **Founder test checklist** — structured first-user interviews, session capture, and pass/fail thresholds for activation proof.
- **Internal feedback panels** — dozens of `/internal/*` routes with live readouts for blind-spot quality, resurfacing timing, paywall attribution, archive moat, mobile parity, and launch readiness.
- **Command center** — single hub linking internal pillars and founder-focus scoring.

### Implementation map

| Concern | Entry points | Code paths |
| --- | --- | --- |
| Founder test validator | `npm run validate:founder-test` | [`scripts/validate-founder-test.mjs`](../scripts/validate-founder-test.mjs) |
| Founder test domain model | — | [`packages/shared/lib/founder-test/`](../packages/shared/lib/founder-test/), [`packages/shared/types/founder-test.ts`](../packages/shared/types/founder-test.ts) |
| Founder test UI | `/internal/founder-test` | [`apps/web/app/internal/founder-test/page.tsx`](../apps/web/app/internal/founder-test/page.tsx), [`apps/web/components/internal/FounderTestPanel.tsx`](../apps/web/components/internal/FounderTestPanel.tsx), [`FounderTestChecklist.tsx`](../apps/web/components/internal/FounderTestChecklist.tsx), [`FounderTestReportPanel.tsx`](../apps/web/components/internal/FounderTestReportPanel.tsx), [`FounderEvolvingValidationPanel.tsx`](../apps/web/components/internal/FounderEvolvingValidationPanel.tsx) |
| Internal command center | `/internal` | [`apps/web/components/internal/InternalCommandCenter.tsx`](../apps/web/components/internal/InternalCommandCenter.tsx), [`apps/web/app/internal/page.tsx`](../apps/web/app/internal/page.tsx), [`packages/shared/lib/internal/`](../packages/shared/lib/internal/) |
| Internal panel library | `/internal/*` routes | [`apps/web/components/internal/`](../apps/web/components/internal/) (60+ panels), [`apps/web/app/internal/`](../apps/web/app/internal/) |
| Mobile parity / archive OS audits | `validate:mobile-web-parity-audit`, `validate:mobile-archive-os` | [`scripts/validate-mobile-web-parity-audit.mjs`](../scripts/validate-mobile-web-parity-audit.mjs), [`apps/web/components/internal/MobileWebParityPanel.tsx`](../apps/web/components/internal/MobileWebParityPanel.tsx) |

### Operating rules

1. **Internal routes are not marketing** — they may surface raw metrics and checklist state; never expose `/internal` without auth guardrails already enforced in web middleware.
2. **Founder test changes** — update checklist IDs, thresholds, and `validate-founder-test.mjs` assertions together.
3. **New validation concepts** — prefer a dedicated internal panel + matching `validate:*` script so the loop stays reproducible.

---

## 3. Organic Alignment on "The Evidence Method"

The team's mental model: **preserve what was actually said, embed it as retrievable facts, and only narrate changes that cite ledger evidence.** Insights are not free-form coaching; they are constrained summaries over `fact_ledger` rows with explicit entry citations and correction hooks.

### Core concepts

| Concept | Meaning |
| --- | --- |
| **Fact ledger** | Append-only store of transcript chunks with 768-d embeddings (Gemini), indexed for cosine similarity (HNSW). |
| **Evidence-backed insight** | API payload includes `citedEntryIds`, confidence band, and kind—never orphan prose. |
| **Corrections** | User-suppressed insights recorded in `insight_corrections` without deleting source entries. |
| **Then vs now / weekly story** | Time-windowed ledger retrieval for comparison and narrative, gated by minimum entry thresholds. |

### Implementation map

| Layer | Code paths |
| --- | --- |
| Schema (canonical) | [`packages/shared/lib/server/evidence-schema.ts`](../packages/shared/lib/server/evidence-schema.ts) — pgvector extension, `fact_ledger`, HNSW index, corrections queue |
| SQL migrations | [`docs/sql/004_fact_ledger_pgvector.sql`](sql/004_fact_ledger_pgvector.sql), [`docs/sql/005_fact_ledger_gemini_768.sql`](sql/005_fact_ledger_gemini_768.sql) (production-safe re-embed guardrails) |
| API schema re-export | [`apps/api/lib/db/schema.ts`](../apps/api/lib/db/schema.ts), [`apps/api/types/insights.ts`](../apps/api/types/insights.ts) |
| Ledger ingest / retrieve | [`apps/api/src/services/ledger/ingest.ts`](../apps/api/src/services/ledger/ingest.ts), [`retrieve.ts`](../apps/api/src/services/ledger/retrieve.ts), [`embeddings.ts`](../apps/api/src/services/ledger/embeddings.ts), [`apps/api/lib/ledger/`](../apps/api/lib/ledger/) |
| Insight APIs | [`apps/api/app/api/insights/evidence/route.ts`](../apps/api/app/api/insights/evidence/route.ts), [`comparison/route.ts`](../apps/api/app/api/insights/comparison/route.ts), [`weekly-story/route.ts`](../apps/api/app/api/insights/weekly-story/route.ts), [`corrections/route.ts`](../apps/api/app/api/insights/corrections/route.ts) |
| Insight services | [`apps/api/src/services/insights/`](../apps/api/src/services/insights/), [`apps/api/lib/insights/`](../apps/api/lib/insights/) |
| Shared insight types | [`packages/shared/types/insights.ts`](../packages/shared/types/insights.ts) (via API aliases) |
| Mobile Evidence Method feature | [`apps/mobile/lib/features/evidence_method/`](../apps/mobile/lib/features/evidence_method/) — record entry session, evidence insight client, cited-entry UI |
| Mobile insight surfaces | [`apps/mobile/lib/widgets/evidence_insight_card.dart`](../apps/mobile/lib/widgets/evidence_insight_card.dart), comparison engine screens |

### Operating rules

1. **No insight without citations** — if the model cannot anchor to `entry_id` rows in `fact_ledger`, return weak confidence or silence (see genericness QA).
2. **Embedding dimension changes** — require explicit migration via `docs/sql/005_*` with `voice_memory.confirm_fact_ledger_reembed` when rows exist.
3. **Clinical / diagnostic framing** — belongs only under `apps/api/src/internal/clinical/`; never on insight API responses.

---

## 4. Pragmatic, Scalable, and Cost-Effective Tech Stack

The stack optimizes for a **small team running a serious archive product**: one Turborepo, typed shared libraries, managed Postgres with vectors, Redis for rate limits, transactional email via Resend, and structured logs via pino—without premature microservices.

### Stack overview

| Technology | Role | Where |
| --- | --- | --- |
| **Turborepo + npm workspaces** | Monorepo orchestration | [`package.json`](../package.json), [`turbo.json`](../turbo.json) |
| **Next.js 15 (App Router)** | Web frontend + API route host | [`apps/web/`](../apps/web/) (Next **15.5.x**), [`apps/api/`](../apps/api/) (custom Node entry + App Router API routes) |
| **TypeScript shared libraries** | Cross-app types, design audits, founder-test, evidence schema | [`packages/shared/`](../packages/shared/) |
| **Flutter** | Canonical consumer app (record, archive, evidence UI) | [`apps/mobile/`](../apps/mobile/) |
| **PostgreSQL + pgvector + HNSW** | Durable ledger, vector similarity | [`packages/shared/lib/server/db.ts`](../packages/shared/lib/server/db.ts), [`evidence-schema.ts`](../packages/shared/lib/server/evidence-schema.ts), [`docs/sql/`](../docs/sql/) |
| **Redis (ioredis)** | Sliding-window rate limits, optional distributed enforcement | [`apps/api/lib/rate-limit/`](../apps/api/lib/rate-limit/), [`docker-compose.yml`](../docker-compose.yml) |
| **Resend** | Production transactional email | [`packages/shared/lib/server/email-mode.ts`](../packages/shared/lib/server/email-mode.ts), [`packages/shared/lib/proof/email-live-check.ts`](../packages/shared/lib/proof/email-live-check.ts) |
| **pino** | Structured API logging with redaction | [`apps/api/lib/utils/logger.ts`](../apps/api/lib/utils/logger.ts), [`packages/shared/lib/server/log-sanitizer.ts`](../packages/shared/lib/server/log-sanitizer.ts) |
| **Docker Compose + Nginx** | Production-shaped local/staging stack | [`docker-compose.yml`](../docker-compose.yml), [`apps/api/Dockerfile`](../apps/api/Dockerfile) |

### Cost and scale posture

- **Vectors in Postgres** — avoids a separate vector DB for V1; HNSW index on `fact_ledger.embedding` keeps retrieval local to the primary store.
- **Gemini 768-d embeddings** — smaller vectors than legacy 1536-d OpenAI paths; migration guarded in SQL.
- **Redis optional but recommended** — rate limiting degrades gracefully when `REDIS_URL` is unset (`apps/api/lib/rate-limit/redis-client.ts`).
- **Email gated by mode** — Resend required in production unless explicitly disabled; proof scripts validate live configuration.

### Operating rules

1. **Shared logic lives in `packages/shared`** — apps import; do not fork types between web and API.
2. **API business logic** — prefer `apps/api/src/services/` with thin `app/api/*/route.ts` handlers.
3. **Mobile is the product** — web supports marketing, internal tooling, and parity validation; ship consumer features in `apps/mobile` first unless the PRD says otherwise.

---

## Documentation Manifest

Canonical docs for **active** decisions. Historical audit snapshots live in [`docs/history/archive/`](history/archive/).

| Document | Purpose |
| --- | --- |
| **[`docs/ENGINEERING_CHARTER.md`](ENGINEERING_CHARTER.md)** (this file) | Engineering baseline, quality gates, Evidence Method, stack |
| [`apps/mobile/docs/V1_PRODUCT_SPEC.md`](../apps/mobile/docs/V1_PRODUCT_SPEC.md) | Product requirements (PRD) |
| [`apps/mobile/docs/V1_PRODUCT_CONTRACT.md`](../apps/mobile/docs/V1_PRODUCT_CONTRACT.md) | Free vs paid, capability contract |
| [`apps/mobile/docs/V1_ARCHITECTURE_TRACE.md`](../apps/mobile/docs/V1_ARCHITECTURE_TRACE.md) | Mobile architecture trace |
| [`apps/mobile/docs/V1_DATA_FLOW.md`](../apps/mobile/docs/V1_DATA_FLOW.md) | End-to-end data flow |
| [`apps/mobile/docs/ARCHIVE_SCREEN_SPEC_V1.md`](../apps/mobile/docs/ARCHIVE_SCREEN_SPEC_V1.md) | Archive screen specification |
| [`docs/history/README.md`](history/README.md) | Index of historical plans vs archived audits |
| [`docs/history/VOICE_MEMORY_PRINCIPLES.md`](history/VOICE_MEMORY_PRINCIPLES.md) | Permanent copy and restraint principles |
| [`docs/sql/004_fact_ledger_pgvector.sql`](sql/004_fact_ledger_pgvector.sql) | Fact ledger DDL reference |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | CI/CD pipeline definition |
| [`README.md`](../README.md) | Monorepo onboarding and stack summary |

---

## Quick reference — daily commands

```bash
# Full validator chain (long-running)
npm run validate

# High-signal subsets
npm run validate:restraint
npm run validate:blind-spot
npm run validate:resurfacing
npm run validate:design-consistency
npm run validate:clinical-quarantine
npm run validate:genericness-qa
npm run validate:founder-test

# Workspace health
npm run typecheck
npm run lint
```

When in doubt: **PRD → this charter → validators → ship.**
