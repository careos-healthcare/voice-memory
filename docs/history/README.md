# Historical documentation

This folder preserves **past planning notes, feature specs, and point-in-time audits** from earlier product iterations. It is not the source of truth for what the product does today.

## Where active decisions live

| Need | Location |
| --- | --- |
| Product requirements (PRD) | [`apps/mobile/docs/V1_PRODUCT_SPEC.md`](../../apps/mobile/docs/V1_PRODUCT_SPEC.md), [`V1_PRODUCT_CONTRACT.md`](../../apps/mobile/docs/V1_PRODUCT_CONTRACT.md) |
| Architecture & data flow | [`apps/mobile/docs/V1_ARCHITECTURE_TRACE.md`](../../apps/mobile/docs/V1_ARCHITECTURE_TRACE.md), [`V1_DATA_FLOW.md`](../../apps/mobile/docs/V1_DATA_FLOW.md) |
| Screen & route specs | [`apps/mobile/docs/ARCHIVE_SCREEN_SPEC_V1.md`](../../apps/mobile/docs/ARCHIVE_SCREEN_SPEC_V1.md), [`V1_ROUTE_INVENTORY.md`](../../apps/mobile/docs/V1_ROUTE_INVENTORY.md) |
| Release & QA checklists | [`apps/mobile/docs/V1_RELEASE_CHECKLIST.md`](../../apps/mobile/docs/V1_RELEASE_CHECKLIST.md) and related files under `apps/mobile/docs/` |
| Generated / live reports | [`docs/`](../) (e.g. `ARCHIVE_RELEVANCE_REPORT.md`, `MOBILE_READINESS_REPORT.md`) |

When implementing or reviewing code, start with the PRD and current technical specs above—not files in this directory.

## What stays here (top level)

Longer-lived reference material that predates the V1 consolidation but may still be useful for context:

- [`VOICE_MEMORY_PRINCIPLES.md`](VOICE_MEMORY_PRINCIPLES.md) — permanent product copy and restraint principles
- [`MEMORY_PIPELINE.md`](MEMORY_PIPELINE.md), [`MEMORY_SURFACING.md`](MEMORY_SURFACING.md) — early pipeline/surfacing notes (superseded in part by V1 specs)
- **Feature plans** — `ARCHIVE_*_PLAN.md`, growth-loop plans, GPT-5 synthesis plans, mobile setup notes
- **Roadmaps & prioritization** — `POST_BETA_RESPONSE_ROADMAP.md`, `NEXT_*_ROI_IMPROVEMENTS.md`, `TOP_10_ARCHIVE_IMPROVEMENTS.md`
- **Beta guardrails** — `BETA_SURFACE_AREA_GUARDRAIL.md`, `BETA_FOUR_FAILURE_RESPONSE_RULES.md`

These are retained for narrative continuity; they do not override the V1 PRD.

## Archived audits (`archive/`)

Completed **point-in-time audits, fix reports, and production-readiness snapshots** live in [`archive/`](archive/). They document what was true on a given date and what was changed in response. They are kept for traceability only.

### Rebrand & naming

- `REBRAND_AUDIT.md` + `REBRAND_FIX_REPORT.md`

### Trait pollution

- `TRAIT_POLLUTION_AUDIT.md` + `TRAIT_POLLUTION_REMOVAL_PLAN.md`

### Paywall redesign

- `PAYWALL_REDESIGN_PLAN.md`
- `PAYWALL_TRIGGER_AUDIT.md`
- `PAYWALL_VARIANT_B_IMPLEMENTATION.md`

### Empty states

- `EMPTY_STATE_AUDIT.md` + `EMPTY_STATE_FIXES.md`

### Theory & counter-evidence

- `PRIMARY_THEORY_AUDIT.md` + `UNIFIED_THEORY_SELECTION_PLAN.md`
- `COUNTER_EVIDENCE_AUDIT.md` + `TOPICAL_COUNTER_EVIDENCE_PLAN.md`

### GPT-5 / model

- `GPT5_PRO_GATING_AUDIT.md`
- `GPT5_EXPANSION_VALIDATION.md`
- `MODEL_AUDIT.md`

### Archive quality & PMF

- `ARCHIVE_PRODUCT_MARKET_FIT_AUDIT.md`
- `ARCHIVE_QUALITY_REPORT.md`
- `ARCHIVE_V2_VALIDATION.md`
- `ARCHIVE_GROWTH_LOOP_VALIDATION.md`

### Production & billing readiness

- `REVENUECAT_PRODUCTION_AUDIT.md` + `REVENUECAT_PRODUCTION_EVIDENCE.md`
- `SETTINGS_PRODUCTION_AUDIT.md`
- `BACKEND_HEALTH_AUDIT.md`
- `REPO_INTEGRITY_AUDIT.md`
- `PRODUCTION_LANGUAGE_AUDIT.md`

### Launch QA

- `POST_DEPLOY_QA.md`
- `FIRST_TIME_USER_TEST.md`
- `TESTFLIGHT_FULL_SUITE_STABILISATION.md`

---

**Rule of thumb:** If it is dated, scoped to a migration or audit pass, or paired as audit → fix report, it belongs in `archive/`. If it defines what we ship now, use the PRD and V1 specs instead.
