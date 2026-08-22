# RevenueCat Production Readiness Audit

**Scope:** `apps/voicememory_mobile` (full Flutter app search)  
**Date:** 2026-05-25  
**Method:** Static code + evidence file review (no code changes)  
**SDK:** `purchases_flutter: ^8.1.0` · native `RevenueCat 5.32.0` (iOS Podfile.lock)

---

## Executive summary

| Area | Verdict |
|------|---------|
| Structural integration (SDK, screens, restore UI) | **PASS** |
| Production store proof (`mobile/evidence/*.json`) | **FAIL** — all flags `false`, empty device/platform |
| Release build wiring (API keys in CI/release commands) | **FAIL** — keys only via `--dart-define`, not in release checklists |
| Firebase purchase analytics | **FAIL** — no billing events |
| Entitlement cache vs store truth | **FAIL** — stale Pro possible after lapse |
| Store product ID verification in repo | **WARNING** — IDs live in RevenueCat/App Store/Play only |

**Overall production readiness:** **NOT READY** for App Store / Play billing until API keys are injected on release builds, RevenueCat dashboard offerings match `PackageType.monthly` / `PackageType.annual`, and `mobile/evidence/revenuecat_store_tested.json` + `restore_purchases_tested.json` are committed with `success: true`.

---

## Checklist (10 items)

### 1. RevenueCat initialization

| Status | **PASS** (structural) · **WARNING** (release without keys) |

**What works**

- Singleton `RevenueCatService` initializes from `AppServices.initialize()` and `resetForTest()` (`lib/services/app_services.dart`).
- `Purchases.configure(PurchasesConfiguration(apiKey))` after key resolution (`lib/billing/revenuecat_service.dart`).
- Customer info listener registered: `Purchases.addCustomerInfoUpdateListener(_onCustomerInfo)`.
- Idempotent: `if (_configured) return;` on repeat init.
- Log level: `debug` in debug, `warn` in release.

**Gaps**

- If configure throws, billing stays disabled with no user-visible startup banner (only `debugPrint`).
- `AppConfig.bundleId` is read but not passed into `PurchasesConfiguration` (comment only); no explicit `appUserID` at configure time.
- `AuthService` never calls `RevenueCatService.logIn` / `logOut` on sign-in/out (`lib/services/auth_service.dart`) — store identity is anonymous until manually linked.

**Files**

| File | Role |
|------|------|
| `lib/billing/revenuecat_service.dart` | `initialize()`, configure, listener |
| `lib/services/app_services.dart` | Startup order: auth → RevenueCat → `BillingService.startListening()` |

**Recommended fixes**

1. After successful sign-in, call `RevenueCatService.instance.logIn(session.userId)` (or stable account id); on sign-out call `logOut()`.
2. Surface a one-line “Subscriptions unavailable” state on Account when `!RevenueCatService.instance.isConfigured` in release builds (optional but reduces support confusion).

---

### 2. API key loading

| Status | **WARNING** (design OK) · **FAIL** (production release path documented without keys) |

**Mechanism**

Keys are **compile-time only** — no secrets in repo (correct):

```dart
// lib/billing/revenuecat_service.dart
REVENUECAT_IOS_API_KEY      // iOS first
REVENUECAT_ANDROID_API_KEY  // Android first
REVENUECAT_API_KEY          // fallback both platforms
```

Empty define → `_apiKey == null` → SDK **not** configured; debug log:

`RevenueCat: disabled — no API key (set REVENUECAT_${PLATFORM}_API_KEY ...)`

**Placeholder / missing keys**

| Location | Finding |
|----------|---------|
| `docs/MOBILE_BUILD_COMMANDS.md` | Example placeholders `appl_xxx`, `goog_xxx` only in **dev** `flutter run` — not in `flutter build appbundle` / `flutter build ios` |
| `docs/IOS_RELEASE_CHECKLIST.md` | Release build snippet has **no** `REVENUECAT_*` defines |
| `docs/ANDROID_RELEASE_CHECKLIST.md` | Same — Stripe browser checkout still documented |
| Repo | No committed `.env` or real keys (good) |
| Terminal evidence | Tests log `RevenueCat: disabled — no API key` when defines absent |

**Files**

| File | Issue |
|------|--------|
| `lib/billing/revenuecat_service.dart` | `_apiKey` getter |
| `docs/MOBILE_BUILD_COMMANDS.md` | Keys documented for `flutter run` only |
| `docs/IOS_RELEASE_CHECKLIST.md` | Outdated Stripe-first release steps |
| `docs/ANDROID_RELEASE_CHECKLIST.md` | Outdated Stripe-first release steps |

**Recommended fixes**

1. Add to **every** release command (CI + docs):

   ```bash
   --dart-define=REVENUECAT_IOS_API_KEY=<public_apple_key> \
   --dart-define=REVENUECAT_ANDROID_API_KEY=<public_google_key>
   ```

2. Store keys in CI secrets (EAS, Codemagic, GitHub Actions, etc.) — never commit.
3. Align iOS/Android checklists with native IAP (remove “Stripe checkout in Safari” as primary path).

---

### 3. Offerings retrieval

| Status | **PASS** (implementation) · **FAIL** (production proof) |

**Implementation**

- `fetchOfferings()` → `Purchases.getOfferings()` with 10s timeout via `withBillingTimeout` (`lib/billing/billing_async_guard.dart`).
- Returns `null` on error (UI treats as unavailable).
- Subscription screen uses **`offerings.current`** only — no hardcoded offering identifier (`lib/screens/mobile_subscription_screen.dart`).
- Packages selected by **`PackageType.monthly`** and **`PackageType.annual`** — not by product id string.

**Production evidence**

`mobile/evidence/revenuecat_store_tested.json`:

```json
"offering_loaded": false,
"success": false
```

**Risks (dashboard / config)**

- If RevenueCat “current” offering is empty or packages are `$rc_monthly` custom types without `monthly`/`annual` types, UI shows “temporarily unavailable” even when SDK is configured.
- `fetchOfferings` timeout returns `null` → same UX as missing offering (no distinction for support).

**Files**

| File | Role |
|------|------|
| `lib/billing/revenuecat_service.dart` | `fetchOfferings()` |
| `lib/screens/mobile_subscription_screen.dart` | `_hasStorePackages`, `_packageForBillingPeriod` |
| `lib/screens/revenuecat_verification_screen.dart` | Loads offerings for evidence export |
| `mobile/evidence/revenuecat_store_tested.json` | **FAIL** — not completed |

**Recommended fixes**

1. In RevenueCat dashboard: set **Current** offering with **Monthly** + **Annual** packages linked to store products.
2. Run `/revenuecat-verify` on physical device; commit evidence with `offering_loaded: true`.
3. Optional: log offering identifier + package count to `ProductAnalytics` when load succeeds (see §8).

---

### 4. Entitlement mapping

| Status | **WARNING** |

**RevenueCat → app**

| Dashboard entitlement ID | Code constant | Mapping |
|--------------------------|---------------|---------|
| Must be exactly `pro` | `RevenueCatService.proEntitlementId = 'pro'` | `info.entitlements.active['pro']` + `isActive` → `BillingTier.pro` |

**Mismatch risks**

| Risk | Detail |
|------|--------|
| RC entitlement not named `pro` | User pays but `isPro` stays false |
| Server vs store IDs | Server returns `unlimited_archive`, etc. (`lib/entitlement/tiers.ts`); mobile RC path sets `entitlementIds: ['pro']` only |
| `isPro` | Derived **only** from `tier == BillingTier.pro`, not from `entitlementIds` list |
| Free placeholder | `PremiumEntitlements.free()` uses `source: 'local_placeholder'` (`lib/models/entitlement.dart`) — internal only, but confusing in logs |

**Merge logic** (`lib/billing/billing_service.dart`):

```dart
if (store.isPro) return store;
return server ?? store;
```

Store wins when Pro; otherwise server (Stripe) can grant Pro without IAP.

**Stale cache bug (premium unlock)**

When RevenueCat is configured and reports **free**, but server fetch times out:

1. `serverEnt = await _cache.load()` may still be **Pro** from an old purchase.
2. `_merge(serverEnt, storeEnt)` returns **serverEnt** (cached Pro).
3. User sees Pro UI / no paywall after subscription lapsed.

Cache is written on Pro paths only; it is **not cleared** when store refresh returns free.

| Severity | **FAIL** for production entitlement accuracy |

**Files**

| File | Fix target |
|------|------------|
| `lib/billing/billing_service.dart` | `_merge`, `loadEntitlements` — prefer `storeEnt` when `_revenueCat.isConfigured`; clear cache when store is free |
| `lib/storage/entitlement_cache.dart` | Add `clear()` or overwrite on downgrade |
| `lib/billing/revenuecat_service.dart` | Confirm RC dashboard entitlement id `pro` |

**Recommended fixes**

1. When `isConfigured && !storeEnt.isPro`, treat as free and `await _cache.save(PremiumEntitlements.free())` (or delete cache).
2. Change merge to: `if (isConfigured) return storeEnt.isPro ? storeEnt : (serverEnt?.isPro == true ? serverEnt! : storeEnt);` (explicit policy).
3. Document in RevenueCat dashboard: entitlement identifier **`pro`** attached to both products.

---

### 5. Purchase flow

| Status | **PASS** (happy path) · **WARNING** (edge cases & analytics) |

**Flow**

1. `/subscription` or `/pricing` → `MobileSubscriptionScreen` (`lib/screens/pricing_screen.dart` re-exports same screen).
2. `_purchase(BillingPeriod)` → `_packageForBillingPeriod` → `BillingService.purchaseNative` → `Purchases.purchasePackage`.
3. Success: SnackBar + `_load()` refresh.
4. Errors: `userFacingErrorMessage` (`lib/api/api_error_message.dart`) maps `StateError` containing `revenuecat` to `SubscriptionCopy.temporarilyUnavailable`.

**Gaps**

| Gap | File |
|-----|------|
| No `PurchasesErrorHelper`/user-cancel detection — cancel may show generic “Purchase could not be completed” | `lib/screens/mobile_subscription_screen.dart` |
| No `ProductAnalytics` on purchase start/success/failure | billing layer |
| Paywall CTA calls `_markSeen()` when opening subscription — user can dismiss paywall without paying | `lib/widgets/value_moment_paywall.dart` |
| `createCheckoutSession()` still on `ApiClient` — unused by mobile UI (dead Stripe path) | `lib/api/api_client.dart` |

**Evidence:** `purchase_completed: false` in `mobile/evidence/revenuecat_store_tested.json`.

**Recommended fixes**

1. Handle `PurchasesErrorCode.purchaseCancelledError` (or SDK equivalent) with silent dismiss / “Purchase cancelled”.
2. `ProductAnalytics.trackStrings('subscription_purchase_completed', {'period': 'monthly'|'yearly'})` (and failure/cancel variants).
3. Physical sandbox purchase + commit evidence JSON.

---

### 6. Restore flow

| Status | **PASS** (implementation) · **FAIL** (production proof) |

**Entry points**

| Route | Screen | API |
|-------|--------|-----|
| `/restore-purchases` | `RestorePurchasesScreen` | `billing.restoreNative()` → `Purchases.restorePurchases()` |
| `/subscription` | Outlined “Restore Purchases” → pushes restore screen | |
| `/revenuecat-verify` | Test restore + journey JSON | Dev / evidence |
| `/restore-production-verify` | Reinstall journey | Dev / evidence |

**Behavior**

- Not configured: shows `SubscriptionCopy.temporarilyUnavailable` — no crash.
- Success: updates `_memory`, saves cache via `restoreNative()`.
- Restore screen exports evidence template (`lib/billing/restore_production_evidence.dart`).

**Evidence**

| File | Status |
|------|--------|
| `mobile/evidence/revenuecat_store_tested.json` | `restore_completed: false` |
| `mobile/evidence/restore_purchases_tested.json` | `success: false` |

**Gaps**

- Restore does not force `loadEntitlements(forceRefresh: true)` on subscription screen when returning (user must re-open or pull reload).
- No analytics event for restore success/failure.

**Recommended fixes**

1. Complete reinstall restore journey; commit `restore_purchases_tested.json`.
2. After restore on `RestorePurchasesScreen`, `context.pop(true)` and subscription screen listens to refresh entitlements.
3. Add `ProductAnalytics.trackStrings('subscription_restore_completed', {...})`.

---

### 7. Premium gating

| Status | **WARNING** |

**Where gating exists (soft paywall only)**

| Surface | Logic | File |
|---------|--------|------|
| Blind spots (2nd visit, 5+ reflections) | `ValueMomentPaywallLogic.shouldShowPostBlindSpot` + `isPro` bypass | `lib/screens/blind_spots_screen.dart`, `lib/billing/value_moment_paywall.dart` |
| Discover (2nd visit) | `shouldShowPostDiscover` | `lib/screens/discover_screen.dart` |
| Discover continuity | `shouldGateContinuity` replaces feed with paywall card | `lib/screens/discover_screen.dart` |
| Paywall widget | Hidden when `entitlements?.isPro == true` | `lib/widgets/value_moment_paywall.dart` |

**Where gating does NOT exist**

- No mobile enforcement of `unlimited_archive`, `deeper_resurfacing`, or `FREE_ARCHIVE_LIMIT` (web: `lib/entitlement/tiers.ts`).
- Archive, record, memory, export, explanations — **no** `isPro` checks found under `lib/` beyond paywall surfaces.
- Pro copy promises (“Export your private archive”, full history) are **marketing on paywall**, not enforced locks.

**Premium unlock bugs**

1. **Stale cache** (see §4) — expired subscribers may remain “Pro” in UI.
2. **Server-only Pro** (Stripe web) works when signed in and API returns `tier: pro` even if RevenueCat unset — intentional merge, but IAP-only testers on device without sign-in won’t see web Pro.
3. **Test** `widget_test.dart` parses `entitlements: ['unlimited_archive']` with `tier: pro` — does not validate RC mapping.

**Recommended fixes**

1. Fix cache/merge downgrade path (§4).
2. Decide product policy: either implement feature flags from `entitlementIds` on mobile or document that v1 gating is paywall-only.
3. If export should be Pro-only, gate `lib/screens/export_screen.dart` with `loadEntitlements()`.

---

### 8. Firebase purchase analytics

| Status | **FAIL** |

**Infrastructure**

- `firebase_analytics` dependency present (`pubspec.yaml`).
- `ProductAnalytics.initialize()` runs after `FirebaseBootstrap` (`lib/services/app_services.dart`).
- Feature modules fire many `ProductAnalytics.trackStrings` events (archive, discoveries, etc.).

**Billing**

- **No** `ProductAnalytics` calls in `lib/billing/**`.
- **No** `logPurchase`, `logSubscribe`, `logEvent` for subscription lifecycle in purchase/restore screens.
- RevenueCat verification journey only writes local JSON — not Firebase.

**Files to extend (recommended event names)**

| Event | When | File |
|-------|------|------|
| `subscription_offerings_loaded` | offerings non-null | `mobile_subscription_screen.dart` |
| `subscription_offerings_failed` | null/timeout | same |
| `subscription_purchase_started` | tap plan | same |
| `subscription_purchase_completed` | `isPro` after purchase | `billing_service.dart` |
| `subscription_purchase_failed` | catch | same |
| `subscription_restore_completed` | restore | `restore_purchases_screen.dart` |

Use string parameters only (matches `trackStrings` sanitizer).

---

### 9. iOS product identifiers

| Status | **WARNING** (app identity OK · store products not in repo) |

**In repo**

| Item | Value | File |
|------|--------|------|
| Bundle ID | `com.voicememory.mobile` | `lib/config/app_config.dart`, Xcode signing |
| URL scheme | `voicememory://` | `docs/IOS_RELEASE_CHECKLIST.md` |
| StoreKit Configuration | **None** (no `.storekit` file in project) | — |
| Hardcoded IAP product IDs | **None** (by design — RevenueCat packages) | — |

**Runtime selection**

- Product IDs appear at runtime from `Package.storeProduct.identifier` on verification screen only.

**Verification**

- Use `/revenuecat-verify` → “Product IDs” row lists identifiers from current offering.
- Must match **App Store Connect** subscriptions linked in RevenueCat iOS app.

**Risks**

- Release checklist still describes **Stripe in Safari** as Pro upgrade — wrong for native-primary mobile.
- Evidence file not completed for iOS.

**Recommended fixes**

1. Create ASC products (monthly + annual); link in RevenueCat; attach to `pro` entitlement.
2. Add optional `StoreKit.storekit` for local Xcode testing (not required if sandbox used).
3. Update `docs/IOS_RELEASE_CHECKLIST.md` for RevenueCat + dart-defines.
4. Commit `revenuecat_store_tested.json` with real `platform: "ios"` and device model.

---

### 10. Android product identifiers

| Status | **WARNING** (app identity OK · store products not in repo) |

**In repo**

| Item | Value | File |
|------|--------|------|
| `applicationId` | `com.voicememory.mobile` | `android/app/build.gradle.kts` |
| `namespace` | `com.voicememory.mobile` | same |
| Play Billing permission | Implicit via `purchases_flutter` / Play Billing Library | transitive |
| Hardcoded product IDs | **None** | — |

**Risks**

- Release signing still **debug** in `buildTypes.release` (blocks Play production — separate from RevenueCat but affects ship).
- Checklist references Stripe browser, not Play subscriptions.
- No `com.android.vending.BILLING` explicit in manifest (usually OK with plugin).

**Recommended fixes**

1. Create Play subscription base plans; link in RevenueCat Android app; map to monthly/annual package types.
2. Fix release signing per `ANDROID_RELEASE_CHECKLIST.md` TODO.
3. Release build with `REVENUECAT_ANDROID_API_KEY` define.
4. Sandbox purchase on internal track; commit evidence with `platform: "android"`.

---

## Cross-cutting findings

### Paywall navigation

| Item | Status |
|------|--------|
| Primary CTA → `/subscription` | **PASS** — paywall, account, archive worth statement |
| Legacy `/pricing` → same `MobileSubscriptionScreen` | **PASS** |
| Drawer `/pricing` visible in debug/non-release nav | **WARNING** — `lib/widgets/scaffold_shell.dart` |
| Deep link to verify routes in **release** | **PASS** — redirected to `/settings` (`lib/config/production_navigation.dart`, `app_router.dart`) |
| Settings links to verify screens | **PASS** — hidden when `kReleaseMode` (`hideIncompleteSurfaces`) |

### Test-only / dev code in production binaries

| Item | Shipped in release APK/IPA? | Mitigation |
|------|-----------------------------|------------|
| `RevenueCatVerificationScreen` | Route exists; nav hidden; redirect on deep link | OK |
| `RestoreProductionVerificationScreen` | Same | OK |
| `RestorePurchasesScreen` evidence JSON UI | **Reachable** — production feature | OK if copy is user-appropriate; hide “commit evidence” in release UI optional |
| `debugPrint('RevenueCat: ...')` | Yes | Low risk |
| `RevenueCatPurchaseJourney` | Only verify screen | OK |
| Screenshot / visual audit routes include `/revenuecat-verify` | Dev tools only | OK |

### Repo validation gates

| Script | Expectation |
|--------|-------------|
| `npm run validate:revenuecat-production` | Fails until `revenuecat_store_tested.json` complete |
| `npm run validate:mobile-primary-product` | Fails without passing commercial evidence |
| `lib/mobile/revenuecat-production-verification.ts` | Structural PASS, evidence FAIL |

---

## File index (billing touchpoints)

| Path | Purpose |
|------|---------|
| `lib/billing/revenuecat_service.dart` | SDK init, offerings, purchase, restore, map `pro` |
| `lib/billing/billing_service.dart` | Merge server + store, cache, purchase/restore wrappers |
| `lib/billing/billing_async_guard.dart` | 10s timeouts |
| `lib/billing/value_moment_paywall.dart` | When to show paywall |
| `lib/billing/subscription_copy.dart` | User-facing billing errors |
| `lib/billing/revenuecat_purchase_journey.dart` | Device test evidence model |
| `lib/billing/restore_production_evidence.dart` | Restore evidence JSON |
| `lib/models/entitlement.dart` | `PremiumEntitlements`, `isPro` |
| `lib/storage/entitlement_cache.dart` | Disk cache |
| `lib/screens/mobile_subscription_screen.dart` | Purchase UI |
| `lib/screens/restore_purchases_screen.dart` | Restore UI |
| `lib/screens/revenuecat_verification_screen.dart` | Sandbox evidence tool |
| `lib/screens/restore_production_verification_screen.dart` | Reinstall restore proof |
| `lib/widgets/value_moment_paywall.dart` | Paywall card + navigation |
| `lib/api/api_client.dart` | `getEntitlements()`, unused `createCheckoutSession()` |
| `lib/services/product_analytics.dart` | Firebase events (no purchase events) |
| `mobile/evidence/revenuecat_store_tested.json` | Production gate — **incomplete** |
| `mobile/evidence/restore_purchases_tested.json` | Production gate — **incomplete** |

---

## Priority action list (before store submission)

1. **FAIL → PASS:** Inject `REVENUECAT_IOS_API_KEY` / `REVENUECAT_ANDROID_API_KEY` into all release CI/build commands and docs.
2. **FAIL → PASS:** Fix entitlement cache merge so lapsed IAP cannot read stale Pro from cache (`billing_service.dart`).
3. **FAIL → PASS:** Run physical-device sandbox purchase + restore; commit both evidence JSON files with `success: true`.
4. **FAIL → PASS:** Add Firebase `ProductAnalytics` events for purchase/restore/offerings.
5. **WARNING:** Wire `RevenueCat.logIn` / `logOut` to auth session.
6. **WARNING:** Align RevenueCat dashboard — entitlement `pro`, current offering, monthly + annual packages ↔ App Store Connect + Play Console SKUs.
7. **WARNING:** Update iOS/Android release checklists (remove Stripe-primary wording).
8. **WARNING:** Decide whether mobile should enforce Pro feature entitlements beyond paywall cards.

---

## Validation commands

```bash
# Structural (repo root)
npm run validate:revenuecat-production

# Flutter
cd apps/voicememory_mobile
flutter analyze
flutter test
```

---

*Audit generated from static analysis. Dashboard product IDs and live offering shapes must be confirmed in RevenueCat + store consoles; they cannot be fully verified from the Flutter tree alone.*
