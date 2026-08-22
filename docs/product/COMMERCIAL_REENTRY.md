# Commercial re-entry prerequisites

**Status:** Billing frozen for focused beta (`V1CapabilityRegistry.storeBilling = false`).  
**Billing code:** Preserved under `apps/mobile/lib/billing/` and related tests — not deleted, not represented as green release evidence.

---

## Prerequisites before re-enabling billing

Product and engineering must sign off on **all** items below before setting `storeBilling = true`, registering paid routes, or requiring purchase/restore release gates.

### 1. Retention and value thresholds (product-approved)

- Useful Evidence Week rate meets the beta decision dashboard green band (see `BETA_DECISION_DASHBOARD.md`).
- Second-save-within-72h and third-save-within-7d denominators show repeatable capture, not one-time curiosity.
- Pattern reviewed (fits / partly fits / corrected) rate supports that possible patterns feel user-validated.

### 2. User-validated useful pattern

- At least one cohort week where users who reach `possible_pattern_eligible` also produce validated `pattern_reviewed` outcomes at target rate.
- No elevated `not_for_me` / hidden rate suggesting overclaiming.

### 3. Pricing research

- Willingness-to-pay study or structured beta feedback on value vs price.
- Monthly and annual price points validated against compute/storage cost model.
- App Store / Play regional pricing matrix drafted.

### 4. Passing billing test matrix

All must pass in sandbox/staging before production billing is enabled:

| Area | Tests / evidence |
|------|------------------|
| Purchase | Sandbox purchase, receipt validation, entitlement grant |
| Restore | Restore on fresh install, family/device transfer |
| Cancellation | Expired entitlement, graceful downgrade copy |
| Refund | Revoked entitlement handling |
| Offline | Purchase/restore deferred until online; no data loss |
| Account change | Sign-out/in, guest migration, namespace isolation |
| Platform review | App Store / Play billing disclosure review |

Existing harness (not required while billing disabled):

- `test/revenuecat_release_config_test.dart`
- `test/features/billing/billing_startup_test.dart`
- `integration_test/revenuecat_production_evidence_test.dart`
- `scripts/validate-revenuecat-production.mjs`

### 5. Store disclosures

- Subscription terms, auto-renewal, cancel path, and privacy links accurate on store listing and in-app.
- No claim that beta users will retain a launch discount unless legally committed.

---

## Re-enable checklist (engineering)

1. Set `V1CapabilityRegistry.storeBilling = true` and restore `com.android.vending.BILLING` in permission allowlist if shipping Android billing.
2. Add billing screens back to `V1ProductionAllowlist.productionRouterScreens`.
3. Register paid routes in `app_router.dart` behind `V1BillingCapability.isProductionReachable`.
4. Restore consumer billing UI (account Pro tile, settings restore) behind the same gate.
5. Set `REVENUECAT_PURCHASES_ENABLED=true` and valid SDK keys in release CI.
6. Flip `release/focused_beta_status.json` → `capabilities.storeBilling.enabled: true`, `livePurchases: true`.
7. Require `purchase_restore` gate pass; do not waive with false evidence.
8. Re-add billing items to `ReleaseEvidencePack.requiredEvidenceItems`.

---

## Later paid boundary (hypothesis — not shipped commitment)

When billing returns, a **plausible** paid tier could include:

| Hypothesis surface | Rationale |
|--------------------|-----------|
| Compute-intensive longitudinal comparisons | Higher API/ML cost; aligns with value after many moments |
| Richer change history | Deeper timeline / cross-period diff beyond beta Archive |
| Verified encrypted backup | Optional cloud backup with explicit consent and audit story |

**Free forever in beta (and likely at launch):** raw moments, playback, correction, basic search, export, deletion, consent controls, app lock.

This boundary is a **hypothesis** for pricing research — not a public promise until product and legal approve store copy.

---

## What stays out of false-green evidence

While billing is disabled, these must **not** block focused-beta release:

- `purchase_restore` gate (conditional → `not_run` or `waived`)
- RevenueCat sandbox purchase evidence
- Paywall route smoke in `ReleaseEvidencePack`

Billing implementation tests may still run in CI on a separate workflow; their pass status must not be conflated with beta readiness.
