# Pro Conversion Audit v1

**Date:** 2026-06-12  
**Scope:** Non-Pro → Pro journey after Revenue Foundation, Pro Lock Moment, Monthly Private Report Preview, Archive Backup Bridge, Pro Evidence Value, Private Archive Report, Weekly Review, and Settings Pro surfaces.

**Protected (unchanged):** RevenueCat, product IDs, entitlements, restore purchases, signing, build numbers, backend, sync, notifications, journal storage, proof thresholds, evidence gates, AI chat.

---

## Core paid reason

Canonical line: **"Pro keeps the longer story."**

Accepted variants in revenue surfaces:

| Surface | Paid-reason copy |
| --- | --- |
| Pro Lock Moment | Pro keeps the longer story — more history, private reports, and evidence over time. |
| Pro Evidence Value | Keep the longer story / Pro keeps more of the pattern history… |
| Monthly Private Report Preview | Pro keeps the longer story — and the longer report history. |
| Archive Backup Bridge | Pro is built around preserving the longer archive. |
| Revenue Foundation | Keep the longer story |
| Private Archive Report preview | Pro keeps every report section. |
| Settings Pro value preview | Deeper long-term evidence history |

All surfaces avoid **more AI**, **better chat answers**, therapy/diagnosis/treatment claims, and live cloud backup/sync promises.

---

## Pro CTA inventory

| Surface | Widget / entry | CTA label | Route / action | Sheet first? |
| --- | --- | --- | --- | --- |
| Pro Lock Moment | `ProLockMomentCard` → `ProLockMomentSheet` | See what Pro keeps | `/subscription` via `onSeePro` | Yes |
| Monthly Private Report Preview | `MonthlyPrivateReportPreviewCard` → sheet | Preview monthly report → See what Pro keeps | `/subscription` | Yes |
| Archive Backup Bridge | `ArchiveBackupBridgeCard` → sheet | How to preserve it → See what Pro keeps | `/subscription` (settings + patterns) | Yes |
| Pro Evidence Value | `ProEvidenceValueCard` → `ProEvidenceValueSheet` | See what Pro keeps | `/subscription` | Yes |
| Private Archive Report | `PrivateArchiveReportCard` | See Pro | `/subscription` when `onSeePro` set | No |
| Weekly Review | `WeeklyArchiveReviewSheet` | Pro Evidence Value / Monthly Preview / `ProMemoryUpgradeBridge` | `/subscription` via `onSeePro` | Optional |
| Settings — Pro value tile | `ListTile` | ArchiveMe Pro | `/pro-preview` (value education) | No |
| Settings — Backup bridge | `ArchiveBackupBridgeCard` | See what Pro keeps | `/subscription` | Yes |
| Record / Archive (legacy bridges) | `ArchiveIntelligenceProBridgeCard`, paywall triggers | See Pro / varied | `/subscription` | Varies |

**Subscription route:** `/subscription` (`MobileSubscriptionScreen` / paywall stack) — unchanged.

**Settings value path:** `/pro-preview` → honest Pro overview; purchase CTA deferred until store setup (`ProValueCopy.purchaseUnavailableNote`). Not a broken path — intentional value-before-paywall.

---

## Gating audit

| Rule | Status |
| --- | --- |
| Pro users hidden from upgrade cards (patterns) | ✓ `isPro: true` blocks Pro Lock, Monthly Preview, Backup Bridge (patterns), Pro Evidence Value |
| Pro users may see Settings backup preservation (no See Pro CTA) | ✓ `showProCta` false when Pro |
| Zero entries — no monetisation | ✓ All audited engines block `entryCount <= 0` / `isZeroEntryState` |
| Before first proof — no lock/report/backup on record | ✓ Post-save gates require first proof payoff |
| Degraded transcript — blocked | ✓ |
| Active review questions — blocked | ✓ |
| Pattern Review Inbox blocking — blocked | ✓ |
| Stacking priority on record post-save | Pro Evidence Value → Pro Lock Moment → Monthly Preview |

---

## Copy guard audit

Banned in revenue feature copy (automated in `ProConversionAuditEngine`):

- more AI, better chat answers, smarter chat
- sync is active, cloud backup included, your archive is backed up
- guaranteed transformation, universal mental health
- therapy, diagnosis, treatment (except negated disclaimers like "not therapy")

Backup/preservation surfaces label planned areas explicitly (`planned Pro area — not live today`).

---

## Code references

| Module | Path |
| --- | --- |
| Audit guards | `lib/features/pro_conversion_audit/` |
| Tests | `test/pro_conversion_path_test.dart` |
| Pro Lock Moment | `lib/features/pro_lock_moment/` |
| Monthly Private Report | `lib/features/monthly_private_report/` |
| Archive Backup Bridge | `lib/features/archive_backup_bridge/` |
| Pro Evidence Value | `lib/features/pro_evidence_value/` |
| Revenue Foundation | `lib/features/revenue_foundation/` |
| Integration | `record_screen.dart`, `archive_belief_screen.dart`, `settings_screen.dart`, `weekly_archive_review_sheet.dart` |

---

## Findings

1. **All audited upgrade bridges route to `/subscription`** via screen-level `onSeePro` callbacks — no broken paths found.
2. **Settings Pro tile** routes to `/pro-preview` (value screen), not direct paywall — by design.
3. **Core paid reason** is consistent across new revenue packs; Monthly Private Report aligned to include "longer story" in v1 audit.
4. **No fixes required** to RevenueCat, routes, or entitlements.

---

## Verification

```bash
cd apps/voicememory_mobile
flutter test test/pro_conversion_path_test.dart
flutter test test/pro_lock_moment_test.dart test/monthly_private_report_preview_test.dart test/archive_backup_bridge_test.dart test/pro_evidence_value_test.dart test/record_screen_framing_copy_test.dart
```
