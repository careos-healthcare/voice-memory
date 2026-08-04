# RevenueCat manual checklist

Manual RevenueCat dashboard and store-sandbox evidence only. Completing repository
checks does not complete any item below.

## Dashboard mapping

- [ ] Record RevenueCat project/app, platform, release candidate, reviewer, and
  date without storing secret keys.
- [ ] Confirm the canonical entitlement is `archive_loop_pro`.
- [ ] Confirm `pro` is accepted only for legacy migration compatibility.
- [ ] Confirm the intended offering is current, or record the explicitly
  configured offering identifier.
- [ ] Confirm the current offering exposes monthly and annual package kinds only.
- [ ] Confirm no lifetime package is available for new purchase.
- [ ] Confirm each package maps to the matching active store product.
- [ ] Confirm restore/transfer behaviour matches the approved account policy.

## SDK and identity

- [ ] Confirm the signed build uses the correct public SDK key for its platform.
- [ ] Confirm production builds do not enable trial, screenshot, reviewer, or
  other entitlement-bypass modes.
- [ ] Confirm login, logout, reinstall, and account switching do not merge
  unrelated customer identities.
- [ ] Confirm active legacy aliases and verified historical non-expiring
  purchasers follow the migration rules in the canonical matrix.

## Sandbox proof

- [ ] On iOS, capture monthly, annual, cancelled purchase, restore after
  reinstall, second-device restore, expiry/refund/revocation, and offline cases.
- [ ] On Android, capture monthly, annual, cancelled purchase, restore after
  reinstall, second-device restore, expiry/refund/revocation, and offline cases.
- [ ] Confirm CustomerInfo activates and revokes the canonical entitlement at
  the expected points.
- [ ] Confirm a verified inactive store result defeats stale cached Pro state.
- [ ] Store only redacted evidence; never store receipts, API keys, account
  credentials, or complete CustomerInfo payloads.

## Sign-off

- [ ] Link `apps/voicememory_mobile/docs/REVENUECAT_PHYSICAL_DEVICE_PROOF.md`.
- [ ] Record unresolved dashboard, identity, purchase, restore, or expiry work
  as `BLOCKED`.
