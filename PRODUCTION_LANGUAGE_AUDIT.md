# Production Language Audit

**Date:** 2026-05-25  
**Scope:** Customer-facing web (`app/`, `components/`, `lib/*copy*`, product surfaces) and mobile (`apps/voicememory_mobile/lib/screens`, `widgets/`, feature copy).  
**Excluded:** Comments, tests, tooling (`tool/`, `scripts/`), `app/internal/`, `app/debug/`, `components/internal/`, `components/debug/`, `lib/internal/`, `lib/debug/`, `lib/founder-test/`, API routes, server-only code.

**Banned terms scanned:** `debug`, `developer`, `verify`, `verification`, `diagnostic`, `diagnostics`, `validation`, `audit`, `internal`, `test`

---

## Summary

| | Count |
|---|--:|
| Customer-visible issues found | 18 |
| Replaced in this pass | 18 |
| Remaining on production surfaces | 0 (engineering terms only behind QA gate or in non-UI code) |
| Risky / intentionally skipped | 12 categories (see below) |

---

## Replacements made

| File | String (before) | Surface | Visible to user | Action required |
|------|-----------------|---------|-----------------|-----------------|
| `apps/voicememory_mobile/lib/screens/account_screen.dart` | Verify and sign in | Mobile Account sign-in | Yes | **Replaced** → `Sign in with code` |
| `components/auth/EmailCodeAuthModal.tsx` | Verifying… / Verify and continue | Web email sign-in modal | Yes | **Replaced** → `Signing in…` / `Continue` |
| `app/account/page.tsx` | Include retention and debug events in encrypted backup… | Web Account backup option | Yes | **Replaced** → `Include optional usage events in encrypted backup…` |
| `apps/voicememory_mobile/lib/features/archive_analyst/archive_analyst_copy.dart` | Tap a recording to verify | Mobile archive analyst | Yes | **Replaced** → `…hear your words again` |
| `lib/product/evidence-archive-preview-copy.ts` | helps test whether it matters | Web archive preview | Yes | **Replaced** → `helps show whether it matters` |
| `lib/archive/continuity-reinforcement-copy.ts` | still testing this theory | Web continuity strip | Yes | **Replaced** → `still weighing this theory` |
| `lib/archive/continuity-reinforcement.ts` | still testing this theory | Web continuity engine | Yes | **Replaced** → `still weighing this theory` |
| `lib/archive/archive-voice.ts` | still testing (preferred signal) | Voice lint registry | No (lint only) | **Replaced** → `still weighing` |
| `lib/theories/theory-copy.ts` | worth testing against new reflections | Web theory fallback | Yes | **Replaced** → `worth checking against…` |
| `lib/product/activation-theory-preview.ts` | history to test it / can test this properly | Web activation preview | Yes | **Replaced** → `name it` / `weigh this with confidence` |
| `lib/tester-onboarding-copy.ts` | short version for testers | Web welcome / privacy-simple | Yes | **Replaced** → `in plain language` |
| `app/pricing/PricingPageClient.tsx` | Developer preview: toggle Pro… | Web pricing (dev-only card) | Yes (founders in dev) | **Replaced** → `Local preview: toggle Pro…` |
| `lib/blind-spots/blind-spot-copy.ts` | experiment to test / test against your history | Web blind-spot review | Yes | **Replaced** → try / compare / check |
| `apps/voicememory_mobile/lib/screens/blind_spots_screen.dart` | One experiment to test | Mobile blind spots | Yes | **Replaced** → `One small experiment to try` |
| `apps/voicememory_mobile/lib/features/daily_discoveries/daily_discovery_engine.dart` | test against new recordings | Mobile Discover | Yes | **Replaced** → `compare against new recordings` |
| `apps/voicememory_mobile/lib/features/archive_explanation_v2/archive_followup_question_engine.dart` | test whether the archive should keep… | Mobile archive explanation | Yes | **Replaced** → `show whether…` |
| `apps/voicememory_mobile/lib/screens/about_screen.dart` | Developer settings unlocked | Mobile About (7-tap unlock) | Yes (QA only) | **Replaced** → `Advanced settings unlocked` |
| `apps/voicememory_mobile/lib/screens/restore_purchases_screen.dart` | Evidence (commit when test passes) | Mobile Restore (was public) | Yes | **Gated** behind `DeveloperSettingsGate`; label → `Restore details (for QA)` |

---

## 1. Remaining matches (acceptable)

These still contain banned terms but are **not** shown to typical customers, or are not user-facing strings.

| Location | Term | Why it remains |
|----------|------|----------------|
| `apps/voicememory_mobile/lib/screens/settings_screen.dart` (+ verification screens) | Developer, verify, diagnostics, debug | Behind **developer settings gate** (7-tap About or debug build) |
| `apps/voicememory_mobile/lib/widgets/debug_only_unavailable.dart` | debug builds, developer settings | Shown only when opening gated routes without unlock |
| `app/internal/**`, `app/debug/**`, `components/internal/**`, `components/debug/**` | All banned terms | **Admin / founder-only** surfaces (excluded from audit scope) |
| Route paths (`/revenuecat-verify`, `/developer-diagnostics`, etc.) | verify, diagnostic | URLs are not UI copy; changing would break QA bookmarks |
| `lib/sync/*`, `lib/server/*`, API handlers | verify, validation, debug | Server / sync implementation, not rendered copy |
| Theme keyword lists (`validation`, `validate` in engines) | validation | **Semantic search** for user journal themes (e.g. approval), not engineering language |
| `life_chapter_engine.dart` — Approval & Validation | validation | **Life chapter title** from user themes, not QA wording |
| `belief_change_detector.dart` — external validation | validation | Quoted user-theme phrase in detection |
| `components/*` `data-testid` attributes | test | Test automation hooks, not visible |
| `lib/blind-spots/delayed-validation.ts` + `DelayedValidationPrompt` | validation | Internal module name; user sees `BLIND_SPOT_PAGE.delayedValidationPrompt` copy only (no banned word in prompt) |
| `lib/distribution/testimonial-store.ts` | test | **Testimonial** product feature name (user-facing word is intentional) |
| Comments and docstrings | various | Excluded per audit rules |

---

## 2. Replacements (detail)

All rows in the **Replacements made** table above were applied in-repo. Auth flows now use **sign-in** language instead of **verify**. Archive continuity uses **weighing** instead of **testing** a theory. Blind-spot experiments use **try / compare / check** instead of **test**. Mobile restore no longer shows QA JSON to production users unless advanced settings are unlocked.

**Tests updated:** `apps/voicememory_mobile/integration_test/production_ui_verify_test.dart` expects `Advanced settings unlocked`.

---

## 3. Risky changes skipped

| Item | Reason skipped |
|------|----------------|
| Settings → Developer section labels (RevenueCat verification, etc.) | QA-only; renaming would confuse engineers matching docs/evidence filenames |
| Verification screen titles and bodies | Gated; strings match committed evidence JSON schemas and runbooks |
| `debug_only_unavailable.dart` message | Accurate for unlock flow; audience is QA |
| Route renames (`*-verify`, `developer-diagnostics`) | Breaking change for deep links, screenshot audits, and CI |
| `lib/auth/auth-value-validation.ts` and internal report copy | Founder internal tooling |
| Blind-spot `delayedValidation*` type and file names | Refactor-only; no user-visible "validation" in prompt text |
| Theme lexicon tokens `validation` / `validate` | Removing would weaken theme detection for real journal content |
| `Approval & Validation` chapter label | Reflects user language in entries, not product engineering |
| `testimonial` / `tester_quote` in Proof Wall | Legitimate product vocabulary |
| Web `app/account` `verifyCode` handler name | Code identifier, not UI |
| Stripe `sk_test_`, `revenuecat_store_tested.json` in internal panels | Internal billing evidence |
| `archive-product-questions` role `"internal"` | Type system for surface audit, not rendered |

---

## Re-run checklist

```bash
# Customer-facing string scan (manual filter still required)
rg -i '\b(debug|developer|verify|verification|diagnostic|diagnostics|validation|audit|internal|test)\b' \
  app components lib apps/voicememory_mobile/lib \
  --glob '!**/internal/**' --glob '!**/debug/**' --glob '!**/*test*' \
  -g '*.tsx' -g '*.ts' -g '*.dart'
```

After changes, run targeted tests:

```bash
cd apps/voicememory_mobile && flutter test test/settings_screen_widget_test.dart
# Web: npm test -- --testPathPattern=blind-spot|activation-theory|continuity  (if present)
```

---

## Sign-off

Production customer paths (record, archive, account sign-in, blind spots, pricing preview card, onboarding privacy-simple) no longer surface the scanned engineering terms. QA and founder tooling retains explicit labels behind gates.
