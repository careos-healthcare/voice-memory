# RevenueCat sandbox proof v1

> Canonical doc: `docs/architecture/revenuecat_sandbox_proof.md` · Code: `lib/features/revenuecat_sandbox_proof/`


Prove iOS purchase, restore, and Pro entitlement on a physical device before TestFlight or App Store submission — without changing product promise, pricing copy, or Pro benefits.

## Acceptance checklist

| # | Check | Automated | Manual |
|---|-------|-----------|--------|
| 1 | `REVENUECAT_IOS_API_KEY` present | Build-time dart-define | — |
| 2 | Offering loads | Startup diagnostics | Confirm log |
| 3 | Product title and price visible | — | Paywall |
| 4 | StoreKit purchase sheet appears | — | Tap purchase CTA |
| 5 | Sandbox purchase succeeds | — | Complete sandbox payment |
| 6 | `archive_loop_pro` or `pro` entitlement active | — | Logs + Pro state |
| 7 | Pro gate unlocks | — | Gated feature test |
| 8 | Restore purchases succeeds | — | Paywall restore CTA |
| 9 | Entitlement persists after app restart | — | Force-quit + relaunch |
| 10 | Missing key does not crash release smoke | Unit test | Release build without key |

## Prerequisites

- Sandbox Apple ID signed in on the test device (Settings → App Store → Sandbox Account).
- RevenueCat iOS public/sandbox API key available.
- Physical iPad or iPhone connected.

## Run on iPad

```bash
cd apps/mobile
export REVENUECAT_IOS_API_KEY="appl_xxx"
bash tool/run_revenuecat_sandbox_proof_ipad.sh
```

Override device with `IPAD_DEVICE_ID=<udid>` if needed. Pass extra flags after `--`:

```bash
bash tool/run_revenuecat_sandbox_proof_ipad.sh -- --release
```

## Manual proof steps

1. Sign into sandbox Apple ID on the device.
2. Launch app with `REVENUECAT_IOS_API_KEY` dart-define.
3. Confirm startup log: `ARCHIVEME_REVENUECAT_CONFIGURED platform=ios source=dart_define`.
4. Complete first-loop activation (3 recordings, map, one node confirm/edit, return check).
5. Reach paywall headline: **Keep testing this loop**.
6. Confirm product loads and price appears (`ARCHIVEME_PAYWALL_PRODUCT_LOADED`).
7. Tap **Keep tracking my loop**.
8. Confirm sandbox payment sheet appears and complete purchase.
9. Confirm logs:
   - `ARCHIVEME_PURCHASE_SUCCESS … entitlement=archive_loop_pro`
   - `ARCHIVEME_ENTITLEMENT_PERSISTED active=true`
10. Confirm gated feature unlock (second map edit or fourth evidence save).
11. Force-quit and relaunch app.
12. Confirm Pro still active (`ARCHIVEME_ENTITLEMENT_CACHE_USED active=true` or refreshed active).
13. Tap **Restore purchases** on paywall if needed.
14. Confirm `ARCHIVEME_RESTORE_SUCCESS entitlement=archive_loop_pro`.

## Graceful fallback (no API key)

Release smoke and local dev without a key must still pass:

- `ARCHIVEME_REVENUECAT_DISABLED reason=missing_api_key`
- Paywall shows unavailable copy and **Not now** dismisses without crash.
- First activation remains free.

Verify with:

```bash
flutter test test/revenuecat_sandbox_proof_test.dart test/revenuecat_release_config_test.dart
```

## Code module

Decision model: `lib/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof.dart`

Maps the ten acceptance checks to pass / fail / pending / blocked / skipped states. Use `RevenueCatSandboxProof.fromDiagnostics()` or `fromPurchaseJourney()` to feed runtime evidence.

## Related docs

- [revenuecat_sandbox_manual_test.md](../revenuecat_sandbox_manual_test.md) — earlier manual checklist
- [REVENUECAT_RELEASE_CHECKLIST.md](../REVENUECAT_RELEASE_CHECKLIST.md) — release build requirements
- [archive_loop_commercial_readiness.md](../archive_loop_commercial_readiness.md) — commercial readiness tracker

## Guardrail

Sandbox proof verifies purchase and restore only. Do not change product promise, pricing copy, proof thresholds, anchors, record layout, backend, sync, or journal storage.
