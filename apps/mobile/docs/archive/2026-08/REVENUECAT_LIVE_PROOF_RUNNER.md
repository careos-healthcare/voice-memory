# RevenueCat live proof runner v1

Manual/live proof runner for iOS sandbox purchase, restore, and entitlement persistence — without changing pricing, Pro promise, or Pro benefits.

## Canonical checklist

| # | Check | Automated | Manual |
|---|-------|-----------|--------|
| 1 | REVENUECAT_IOS_API_KEY present | Build-time dart-define | — |
| 2 | Offering loads | Startup diagnostics | Confirm log |
| 3 | Product identifier matches App Store Connect | Diagnostics product id | Compare App Store Connect |
| 4 | Price visible | — | Paywall |
| 5 | Paywall route opens | — | Reach paywall from Pro gate |
| 6 | Purchase button enabled | — | Confirm CTA enabled |
| 7 | StoreKit sheet appears | — | Tap purchase CTA |
| 8 | Sandbox purchase succeeds | — | Complete sandbox payment |
| 9 | Entitlement active after purchase | — | Logs + Pro state |
| 10 | Pro gate unlocks | — | Gated feature test |
| 11 | App restart keeps entitlement | — | Force-quit + relaunch |
| 12 | Restore purchases succeeds | — | Paywall restore CTA |
| 13 | Restore after reinstall succeeds | — | Delete app, reinstall, restore |
| 14 | Missing product/failure shows calm fallback | Repo signal + manual | No-key build |
| 15 | No crash | Unit test + manual | Full journey |

### Canonical checklist (15)

1. REVENUECAT_IOS_API_KEY present
2. Offering loads
3. Product identifier matches App Store Connect
4. Price visible
5. Paywall route opens
6. Purchase button enabled
7. StoreKit sheet appears
8. Sandbox purchase succeeds
9. Entitlement active after purchase
10. Pro gate unlocks
11. App restart keeps entitlement
12. Restore purchases succeeds
13. Restore after reinstall succeeds
14. Missing product/failure shows calm fallback
15. No crash

## Prerequisites

- Sandbox Apple ID signed in on the test device (Settings → App Store → Sandbox Account).
- RevenueCat iOS public/sandbox API key available.
- Physical iPhone or iPad connected.

## Run automated checklist validation

```bash
cd apps/mobile
bash tool/run_revenuecat_live_proof_checklist.sh
```

## Run live proof on physical device

```bash
cd apps/mobile
export REVENUECAT_IOS_API_KEY="appl_xxx"
bash tool/run_revenuecat_sandbox_proof_ipad.sh
```

Override device with `IPAD_DEVICE_ID=<udid>` if needed.

## Manual proof steps

1. Sign into sandbox Apple ID on the device.
2. Launch app with `REVENUECAT_IOS_API_KEY` dart-define.
3. Confirm startup log: `ARCHIVEME_REVENUECAT_CONFIGURED platform=ios source=dart_define`.
4. Complete first-loop activation (3 recordings, map, one node confirm/edit, return check).
5. Reach paywall headline: **Keep testing this loop**.
6. Confirm product loads with expected identifier (`archive_loop_pro_monthly` or `archive_loop_pro_yearly`).
7. Confirm price appears (`ARCHIVEME_PAYWALL_PRODUCT_LOADED`).
8. Tap **Keep tracking my loop**.
9. Confirm sandbox payment sheet appears and complete purchase.
10. Confirm logs:
    - `ARCHIVEME_PURCHASE_SUCCESS … entitlement=archive_loop_pro`
    - `ARCHIVEME_ENTITLEMENT_PERSISTED active=true`
11. Confirm gated feature unlock (second map edit or fourth evidence save).
12. Force-quit and relaunch app.
13. Confirm Pro still active (`ARCHIVEME_ENTITLEMENT_CACHE_USED active=true` or refreshed active).
14. Tap **Restore purchases** on paywall.
15. Confirm `ARCHIVEME_RESTORE_SUCCESS entitlement=archive_loop_pro`.
16. Delete app, reinstall, tap restore, confirm Pro returns.

## Graceful fallback (no API key)

Release smoke and local dev without a key must still pass:

- `ARCHIVEME_REVENUECAT_DISABLED reason=missing_api_key`
- Paywall shows unavailable copy and **Not now** dismisses without crash.
- First activation remains free.

## Code module

Decision model: `lib/features/revenuecat_live_proof/revenuecat_live_proof_runner.dart`

Maps the fifteen acceptance checks to pass / fail / pending / blocked states. Use `RevenueCatLiveProofRunner.fromDiagnostics()` or `fromPurchaseJourney()` to feed runtime evidence.

## Guardrail

Do not treat automated tests as purchase proof. Live proof verifies purchase and restore only. Do not change pricing, Pro promise, Pro benefits, proof thresholds, record layout, backend, or sync.

## Related docs

- [revenuecat_sandbox_proof.md](architecture/revenuecat_sandbox_proof.md) — earlier ten-step sandbox proof
- [REVENUECAT_RELEASE_CHECKLIST.md](REVENUECAT_RELEASE_CHECKLIST.md) — release build requirements
- [archive_loop_commercial_readiness.md](archive_loop_commercial_readiness.md) — commercial readiness tracker
