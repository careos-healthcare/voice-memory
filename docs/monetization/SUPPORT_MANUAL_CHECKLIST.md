# Monetization support manual checklist

Manual support and FAQ review only. Do not publish a price, availability claim,
or incident result from this template.

## Required support answers

- [ ] Explain that displayed prices and billing periods come from the user's
  storefront.
- [ ] Explain how to purchase, restore, and manage or cancel a subscription on
  each supported platform.
- [ ] Explain what Free includes and what requires Pro using the canonical
  matrix, without inventing limits.
- [ ] Explain that original content and existing readable output remain
  accessible after expiry as defined by the matrix.
- [ ] Explain expected offline behaviour without promising server-backed work
  while disconnected.
- [ ] Explain the legacy-purchaser path without advertising a new lifetime plan.
- [ ] Link privacy, export, content deletion, and account-deletion instructions.

## Incident triage

- [ ] Capture platform, app version/build, anonymized app user identifier,
  product/package kind, approximate timestamp, and user-visible error.
- [ ] Ask whether purchase, restore, renewal, expiry, refund, family/account
  transfer, or storefront loading failed.
- [ ] Never request a password, full receipt, API key, payment-card data, or
  unredacted CustomerInfo payload.
- [ ] Distinguish a store charge from an active RevenueCat entitlement before
  suggesting another purchase.
- [ ] Escalate entitlement corrections through the approved billing-support
  process; do not grant access from a support document.

## Publication evidence

- [ ] Confirm the public support URL loads without authentication.
- [ ] Review FAQ text against `MONETIZATION_CONTRACT.md` and the current
  generated policy.
- [ ] Record reviewer, date, published revision, and privacy-safe evidence link.
- [ ] Keep the item `BLOCKED` if published content cannot be inspected.
