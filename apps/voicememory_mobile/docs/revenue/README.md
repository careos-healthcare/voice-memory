# ArchiveMe — Revenue & differentiation docs

Strategy and positioning documentation only. **Do not treat these docs as product specs** until validated with beta feedback.

---

## Index

| Doc | Purpose |
| --- | --- |
| [POSITIONING.md](./POSITIONING.md) | What ArchiveMe is, core loop, one-line options |
| [CHATGPT_DIFFERENTIATION.md](./CHATGPT_DIFFERENTIATION.md) | ArchiveMe vs ChatGPT — memory vs conversation |
| [PRO_VALUE_LADDER.md](./PRO_VALUE_LADDER.md) | Free vs Pro — what exists today vs **Future** |
| [PRICING_HYPOTHESES.md](./PRICING_HYPOTHESES.md) | Price points and willingness-to-pay questions |
| [REVENUE_EXPERIMENTS.md](./REVENUE_EXPERIMENTS.md) | Experiments A–H with hypotheses and metrics |
| [LANDING_PAGE_COPY.md](./LANDING_PAGE_COPY.md) | Web landing draft sections |
| [TESTFLIGHT_REVENUE_SCRIPT.md](./TESTFLIGHT_REVENUE_SCRIPT.md) | Tester interview questions for monetization learning |
| [DO_NOT_BUILD_YET.md](./DO_NOT_BUILD_YET.md) | Scope guardrails before beta feedback |
| [NEXT_PRODUCT_BETS.md](./NEXT_PRODUCT_BETS.md) | Ranked future bets after validation |
| [PAID_REASON_V1.md](./PAID_REASON_V1.md) | Canonical paid reason — memory not AI |
| [LONG_TERM_ARCHIVE_HISTORY.md](./LONG_TERM_ARCHIVE_HISTORY.md) | Longer history value pillar |
| [PRIVATE_REPORTS_AND_EXPORTS.md](./PRIVATE_REPORTS_AND_EXPORTS.md) | Reports & export honesty |
| [SAFE_SHARING_STRATEGY.md](./SAFE_SHARING_STRATEGY.md) | Future-safe sharing without medical claims |
| [REVENUE_BUILD_SEQUENCE.md](./REVENUE_BUILD_SEQUENCE.md) | Phased build order — no billing changes |

---

## Code reference (safe copy only)

- `lib/features/revenue_foundation/` — value flags and canonical copy (`revenue_value_engine.dart`)

---

## Related docs (outside this folder)

- `docs/beta/` — TestFlight tester materials  
- `docs/APP_STORE_COPY.md` — store listing draft  
- `docs/ARCHIVE_INTELLIGENCE_PROOF_SECTION.md` — paywall proof surfaces  
- `lib/billing/archive_pro_feature_map.dart` — **code reference only**; do not change from docs work  

---

## Principles

1. **Monetize long-term memory**, not AI replies.  
2. **ArchiveMe is not ChatGPT** — it records, compares, and preserves evidence over time.  
3. **No feature builds** from this folder until TestFlight feedback is triaged.  
4. **Protected areas** (billing implementation, gates, backend) stay unchanged during strategy work.

---

## Current commercial state (July 2026)

- Release suite: **+413 all tests passed**  
- RevenueCat / purchases may be **paused or inert** on TestFlight  
- Pro value is defined in product copy and soft gates; full enforcement is still evolving  
- Priority: **learn willingness to pay** before expanding SKUs or subscriptions  

See `docs/beta/BETA_RELEASE_STATUS.md` for release status.
