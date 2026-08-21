# ArchiveMe — Revenue build sequence

**Purpose:** Order of operations for paid conversion foundation — strategy and safe code only. **Does not authorize billing or backend changes.**

---

## Phase 0 — Protected (never skip)

Do not change without explicit release task:

- RevenueCat, product IDs, entitlements, restore purchases
- Signing, build numbers
- Backend, sync, notifications
- Journal storage, proof thresholds, evidence quality gates
- AI chat surfaces

---

## Phase 1 — Foundation (this pack)

| Deliverable | Status |
| --- | --- |
| Paid reason v1 doc | Done — [PAID_REASON_V1.md](./PAID_REASON_V1.md) |
| Long-term history doc | Done — [LONG_TERM_ARCHIVE_HISTORY.md](./LONG_TERM_ARCHIVE_HISTORY.md) |
| Private reports & exports doc | Done — [PRIVATE_REPORTS_AND_EXPORTS.md](./PRIVATE_REPORTS_AND_EXPORTS.md) |
| Safe sharing strategy doc | Done — [SAFE_SHARING_STRATEGY.md](./SAFE_SHARING_STRATEGY.md) |
| `revenue_foundation` copy/model/engine | Safe flags + copy only |
| Pro evidence value bridge (in-app) | Separate pack — do not merge billing |

**Exit criteria:** Copy tests pass; beta feedback intelligence captures ChatGPT difference + would-pay signals.

---

## Phase 2 — Validate (TestFlight)

1. Run [TESTFLIGHT_REVENUE_SCRIPT.md](./TESTFLIGHT_REVENUE_SCRIPT.md)
2. Triage via `docs/beta/FEEDBACK_TRIAGE.md`
3. Run experiments in [REVENUE_EXPERIMENTS.md](./REVENUE_EXPERIMENTS.md) — one at a time
4. Confirm purchases path in [DO_NOT_BUILD_YET.md](./DO_NOT_BUILD_YET.md) before turning billing on

**Exit criteria:** ≥5 testers articulate paid reason in their own words; no confusion that ArchiveMe is a chatbot.

---

## Phase 3 — Harden Pro surfaces (product)

Only after Phase 2 signal:

1. Align paywall copy with `revenue_value_copy.dart`
2. Uniform Pro gates on history ceiling, timeline, export preview
3. Export/report labels match **live** vs **planned** flags in engine
4. App Store copy from [LANDING_PAGE_COPY.md](./LANDING_PAGE_COPY.md) + honesty audit

**Still no:** sync, family sharing, coach dashboard.

---

## Phase 4 — Expand SKUs (future)

After billing verified in production:

- Annual framing tests ([PRICING_HYPOTHESES.md](./PRICING_HYPOTHESES.md))
- Private report export as primary Pro proof
- Optional: read-only share link (see [SAFE_SHARING_STRATEGY.md](./SAFE_SHARING_STRATEGY.md))

---

## Feature live matrix (reference)

| Feature | Consumer promise | Code flag |
| --- | --- | --- |
| Long-term history | Live (positioning) | `longTermHistoryLive` |
| Private reports | Partial | `privateReportsLive` |
| Export reports | Partial / planned | `exportReportsLive` |
| Safe sharing | **Future only** | `safeSharingLive = false` |
| Sync / backup | **Future only** | never in consumer copy |

---

## Related

- [README.md](./README.md)
- [NEXT_PRODUCT_BETS.md](./NEXT_PRODUCT_BETS.md)
- `lib/features/revenue_foundation/` — canonical value flags
