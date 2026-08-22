# RevenueCat End-to-End Production Audit

**Audit date:** 2026-06-03 (UTC)  
**Method:** Live integration test on device — **runtime evidence only** (no pass from code inspection)  
**Overall:** **FAIL** — **0 / 12** steps passed

| Summary | Value |
|---------|--------|
| **Device** | `sdk gphone16k arm64` — Android Emulator `emulator-5554`, API 37 |
| **App** | `com.voicememory.app` debug build via `integration_test/revenuecat_e2e_audit_test.dart` |
| **Sandbox account** | **Not used** |
| **RevenueCat API keys in build** | **Absent** — no `REVENUECAT_*` dart-define; no keys in repo `.env*` files |
| **Runtime JSON** | [revenuecat_e2e_runtime.json](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/revenuecat_e2e_runtime.json) |
| **Re-run command** | See [How to re-run](#how-to-re-run-with-real-keys) |

---

## Aggregate RevenueCat logs (device console)

Captured from `flutter test integration_test/revenuecat_e2e_audit_test.dart -d emulator-5554`:

```
AppConfig: debug API base → http://10.0.2.2:3000
RevenueCat: startup — platform=android
RevenueCat: disabled — no API key (set REVENUECAT_ANDROID_API_KEY or REVENUECAT_API_KEY at build time)
RC_E2E: platform=android
RC_E2E: sdk_configured=false
Billing: server entitlements timed out — using cache
RC_E2E: entitlements_after_init=free; pro=false; ids=; source=local_placeholder
RC_E2E: RevenueCat: disabled — no API key at build time
RC_E2E: archive_intelligence_gate=false
RC_E2E: offline_cache=empty
```

**Interpretation:** `Purchases.configure` never ran. Offerings, purchase, restore, and dashboard transaction were **not reachable** in this run.

---

## Step-by-step results

### 1. RevenueCat initializes successfully

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step01_sdk_init.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step01_sdk_init.png) |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | `RevenueCat: disabled — no API key (set REVENUECAT_ANDROID_API_KEY or REVENUECAT_API_KEY at build time)` |
| **Entitlement state** | `free; pro=false; ids=; source=local_placeholder` |

---

### 2. Offerings load

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step02_offerings.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step02_offerings.png) — RevenueCat verify: **Offerings loaded: no** |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | `fetchOfferings` not invoked (`sdk_configured=false`) |
| **Entitlement state** | `free; pro=false` |

---

### 3. Monthly product loads

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step03_monthly_product.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step03_monthly_product.png) — subscription screen: products unavailable |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | No `PackageType.monthly` resolved |
| **Entitlement state** | `free; pro=false` |

---

### 4. Annual product loads

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step04_annual_product.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step04_annual_product.png) — no yearly plan row |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | No `PackageType.annual` resolved |
| **Entitlement state** | `free; pro=false` |

---

### 5. Purchase flow completes

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step05_purchase.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step05_purchase.png) |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | Purchase not attempted — blocked at SDK init |
| **Entitlement state** | `free; pro=false` |
| **Notes** | Requires sandbox IAP + configured SDK; not executed in this run |

---

### 6. RevenueCat dashboard shows transaction

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step06_rc_dashboard.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step06_rc_dashboard.png) |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | No transaction — no purchase |
| **Entitlement state** | `free; pro=false` |
| **Notes** | Dashboard screenshot not captured; no runtime purchase to verify |

---

### 7. Entitlement `pro` becomes active

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step07_pro_entitlement.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step07_pro_entitlement.png) |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | `entitlements.active['pro']` never observed |
| **Entitlement state** | `free; pro=false; ids=; source=local_placeholder` |

---

### 8. Archive Intelligence unlocks

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step08_archive_unlock.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step08_archive_unlock.png) |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | `archive_intelligence_gate=false` |
| **Entitlement state** | `free; pro=false` — `ArchiveSynthesisProGate.canAccessArchiveIntelligence` returned false |

---

### 9. App restart preserves entitlement

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step09_restart.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step09_restart.png) |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | Cold restart with Pro not tested |
| **Entitlement state** | `free; pro=false` |
| **Notes** | Not executed — no Pro state to preserve |

---

### 10. Restore purchases works

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step10_restore.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step10_restore.png) |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | `Purchases.restorePurchases()` not run with active subscription |
| **Entitlement state** | `free; pro=false` |

---

### 11. Fresh install restores entitlement

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step11_fresh_install.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step11_fresh_install.png) |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | Reinstall + restore journey not executed |
| **Entitlement state** | `free; pro=false` |
| **Notes** | Use `/restore-production-verify` on physical device after sandbox purchase |

---

### 12. Offline entitlement cache works

| Field | Value |
|-------|--------|
| **Result** | **FAIL** |
| **Screenshot** | [step12_offline_cache.png](apps/voicememory_mobile/tool/screenshots/revenuecat_e2e/step12_offline_cache.png) |
| **Device** | sdk gphone16k arm64 (emulator-5554) |
| **RevenueCat logs** | `offline_cache=empty` — no Pro written to disk cache |
| **Entitlement state** | `free; pro=false` |
| **Notes** | Cache read ran; cannot prove offline Pro without prior purchase |

---

## Scorecard

| # | Step | Result |
|---|------|--------|
| 1 | SDK initializes | **FAIL** |
| 2 | Offerings load | **FAIL** |
| 3 | Monthly product | **FAIL** |
| 4 | Annual product | **FAIL** |
| 5 | Purchase completes | **FAIL** |
| 6 | RC dashboard transaction | **FAIL** |
| 7 | `pro` active | **FAIL** |
| 8 | Archive Intelligence unlocks | **FAIL** |
| 9 | Restart preserves Pro | **FAIL** |
| 10 | Restore works | **FAIL** |
| 11 | Fresh install restore | **FAIL** |
| 12 | Offline cache | **FAIL** |

**Pass count:** 0 · **Fail count:** 12

---

## Blocker

Production E2E cannot pass until the app is built with RevenueCat public SDK keys and tested on a **physical device** (or Play-licensed emulator) with a **sandbox store account**:

```bash
cd apps/voicememory_mobile
flutter test integration_test/revenuecat_e2e_audit_test.dart \
  -d <physical-device-id> \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_<your_public_key> \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_<your_public_key>
```

Then manually: sandbox purchase → confirm Pro in app → screenshot RevenueCat dashboard → delete app → reinstall → restore → update this document with PASS rows and dashboard screenshot path.

**Wireless device available (not used this run):** Chirag Patel's iPad — `00008112-000145A81E07401E`, iOS 26.5

---

## How to re-run with real keys

```bash
cd apps/voicememory_mobile
flutter test integration_test/revenuecat_e2e_audit_test.dart -d emulator-5554 \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_YOUR_KEY

mkdir -p tool/screenshots/revenuecat_e2e
adb pull /sdcard/Download/revenuecat_e2e/. tool/screenshots/revenuecat_e2e/
```

After manual sandbox purchase, export evidence from **Settings → RevenueCat verify** and commit `mobile/evidence/revenuecat_store_tested.json` with `success: true`.

---

## Validation gate

```bash
npm run validate:revenuecat-production
# FAILED — evidence incomplete (expected until steps 1–11 pass on device)
```

---

*This report is based solely on runtime output from 2026-06-03. Steps 5–11 require human sandbox purchase and RevenueCat dashboard access; they are marked FAIL because that proof was not produced in this audit run.*
