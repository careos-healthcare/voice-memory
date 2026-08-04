# Monetization store manual checklist

Manual App Store Connect and Play Console evidence only. This checklist does not
claim that any external product, agreement, price, or submission exists.

## Product configuration

- [ ] Record the store, app identifier, release candidate, reviewer, and date.
- [ ] Confirm only monthly and annual packages are available for new purchase.
- [ ] Confirm no lifetime package is available for new purchase.
- [ ] Confirm each store product is linked to the intended RevenueCat package
  kind and canonical entitlement `archive_loop_pro`.
- [ ] Confirm the live localized title, duration, price, trial, and renewal terms
  match the store console; do not copy a hypothesis price into metadata.
- [ ] Confirm agreements, tax, banking, product status, and territory availability
  directly in each store console.

## Listing and review material

- [ ] Confirm listing copy distinguishes Free proof from ongoing Pro generation
  without promising a capability absent from the matrix.
- [ ] Confirm screenshots show the same purchase state as the submitted build.
- [ ] Confirm privacy policy, terms, and support URLs load publicly.
- [ ] Confirm App Review / Play review notes explain how to reach the paywall and
  Restore Purchases.
- [ ] Confirm release notes do not say purchases are available until the submitted
  product and sandbox flows have passed.

## Evidence

- [ ] Attach privacy-safe screenshots of product status and package mapping.
- [ ] Attach the submitted build identifier and processing/review status.
- [ ] Link physical-device purchase and restore evidence for each platform.
- [ ] Record unresolved store warnings or rejections as `BLOCKED`.
