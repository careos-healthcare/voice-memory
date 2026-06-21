# RevenueCat sandbox manual test — ArchiveMe loop-map Pro

Use this checklist when automated sandbox purchase cannot complete in CI.

## Prerequisites

- Sandbox Apple ID signed in on the test device (Settings → App Store → Sandbox Account).
- RevenueCat iOS public/sandbox API key available.
- ArchiveMe built with:

```bash
export REVENUECAT_IOS_API_KEY="<your_ios_key>"
bash tool/run_archive_loop_revenuecat_sandbox_ipad.sh
```

## Manual checklist

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
