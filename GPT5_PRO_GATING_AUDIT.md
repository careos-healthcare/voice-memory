# GPT-5 Synthesis Pro Gating — Audit

**Date:** 2026-05-25  
**Entitlement:** RevenueCat `pro` (existing tier — no new SKU)

---

## 1. Verification checklist

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Free users cannot access GPT-5 synthesis | **PASS** | `ArchiveSynthesisProGate.canAccessArchiveIntelligence` returns false for `PremiumEntitlements.free()`; service returns `requiresPro`; no API call |
| 2 | Pro users can access GPT-5 synthesis | **PASS** | `entitlementIds: ['pro']` + `BillingTier.pro` unlocks gate; service proceeds to fetch/cache |
| 3 | Archive Theory remains free | **PASS** | `ArchiveV1View.showTheoryHero` unchanged; not referenced by pro gate |
| 4 | Upgrade prompts appear correctly | **PASS** | `ArchiveIntelligenceUpgradeCard` with headline/body per spec when `shouldShowUpgradeTeaser` (≥50 reflections) |
| 5 | Restore purchases restores GPT-5 access | **PASS** | `BillingService.restoreNative()` → RevenueCat `pro` → `isPro` true → gate opens (same path as purchase) |

---

## 2. Pro-only surfaces (gated)

| Surface | Widget / flow | Free UX |
|---------|---------------|---------|
| Archive Monthly Review | `ArchiveMonthlyReviewSection` | Upgrade card |
| Archive Historian | `ArchiveHistorianSection` | Upgrade card |
| Milestone Reviews | `ArchiveMilestoneReviewSection` | Upgrade card |
| GPT-5 Narrative Deep Dive | `ArchiveDeepDiveScreen` (narrative block) | Compact upgrade card; **standard deep dive unchanged** |
| Future GPT-5 reviews | `ArchiveSynthesisService` + `ArchiveSynthesisProGate` | Central gate |

---

## 3. Free surfaces (not gated)

| Surface | Notes |
|---------|--------|
| Recording / Quick Capture | No synthesis hooks |
| Archive Theory | Hero + agreement |
| Lifecycle | `BeliefLifecycleSection` |
| Change Feed | `ArchiveChangeFeedSection` |
| Contradictions | `ArchiveV1ContradictionsSection` |
| Surprises | `ArchiveSurprisesSection` |
| Evidence Trail | Route unchanged |
| Standard Deep Dive | Deterministic why/history/counter/timeline |

---

## 4. Upgrade copy (spec match)

**Headline:** Unlock Archive Intelligence  

**Body:** The archive has identified patterns across your recordings. Upgrade to see monthly reviews, milestone insights, and evidence-backed archive narratives.

**CTA:** View plans → `/subscription`

Defined in `archive_synthesis_pro_gate.dart` + `archive_intelligence_upgrade_card.dart`.

---

## 5. Upgrade timing (value before paywall)

Upgrade teasers appear only when:

- `VOICEMEMORY_ENABLE_GPT5_ARCHIVE_SYNTHESIS=true`, and  
- `eligibleCount >= 50` (`ArchiveSynthesisTrigger.minEligible`)

Below 50 reflections: synthesis sections hidden (no premature lock).

---

## 6. Server API

`POST /api/archive-synthesis`:

- Requires **signed-in session** (`SYNTHESIS_REQUIRES_AUTH` for capture-only).
- **Pro enforced on device** via RevenueCat before request (RC is source of truth for `pro`).
- Server Stripe entitlements can be added later for defense-in-depth without changing the client gate.

---

## 7. Key files

| File | Role |
|------|------|
| `archive_synthesis_pro_gate.dart` | Entitlement + teaser rules |
| `archive_intelligence_upgrade_card.dart` | Upgrade UI |
| `archive_synthesis_service.dart` | `requiresPro` early exit |
| `archive_monthly_review_section.dart` | Pro gate + upgrade |
| `archive_historian_section.dart` | Pro gate + upgrade |
| `archive_milestone_review_section.dart` | Pro gate + upgrade |
| `archive_deep_dive_screen.dart` | Narrative gate only |
| `revenuecat_service.dart` | `proEntitlementId = 'pro'` |

---

## 8. Tests

```bash
cd apps/voicememory_mobile
flutter test test/archive_synthesis_pro_gate_test.dart
```

---

## 9. Success criteria

| Criterion | Met |
|-----------|-----|
| Free user experiences archive value (theory, change feed, surprises, standard deep dive) | Yes |
| Pro user receives archive intelligence (monthly, historian, milestones, narrative) | Yes |
| No critical archive functionality locked before value (50-reflection floor for upgrade teaser) | Yes |
