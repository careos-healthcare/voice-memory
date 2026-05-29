# Stripe Live Integration Report

**Generated:** 2026-05-29T07:04:45.959Z

| Field | Value |
|-------|-------|
| Env configured | false |
| Code integration | PASS |
| Price lookup | skipped |
| Webhook proof | MANUAL_PROOF_REQUIRED |
| Live Stripe env ready | false |

## Checks

- **FAIL** STRIPE_SECRET_KEY: Missing.
- **FAIL** STRIPE_WEBHOOK_SECRET: Missing.
- **FAIL** STRIPE_PRO_PRICE_ID: Missing.
- **FAIL** NEXT_PUBLIC_APP_URL: Missing.
- **PASS** Checkout uses Stripe SDK: POST /api/billing/checkout creates subscription session via Stripe SDK.
- **PASS** Checkout uses server price id: Line items use STRIPE_PRO_PRICE_ID from server config only.
- **PASS** Webhook signature verification: Webhook uses STRIPE_WEBHOOK_SECRET via constructEvent.
- **PASS** Webhook idempotency: Duplicate event ids are skipped before side effects.
- **PASS** Handler: checkout.session.completed: checkout.session.completed
- **PASS** Handler: customer.subscription.created: customer.subscription.created
- **PASS** Handler: customer.subscription.updated: customer.subscription.updated
- **PASS** Handler: customer.subscription.deleted: customer.subscription.deleted
- **PASS** Handler: invoice.payment_failed: invoice.payment_failed
- **PASS** Entitlement: checkout completed: Grants pro after subscription retrieve.
- **PASS** Entitlement: subscription active: active/trialing → pro tier.
- **PASS** Entitlement: payment failed: past_due + free tier (no pro grant).
- **PASS** Entitlement: subscription canceled/deleted: Deleted subscription revokes pro.
- **PASS** Stripe config fail-closed: All four Stripe env vars required to enable billing.
- **PASS** STRIPE_PRO_PRICE_ID server-only: STRIPE_PRO_PRICE_ID only used server-side.
- **SKIP** STRIPE_PRO_PRICE_ID lookup: Stripe env incomplete — skip API lookup.
- **MANUAL** Webhook end-to-end proof: Run Stripe CLI or dashboard test — then set STRIPE_WEBHOOK_LIVE_PROOF=1.
- **PASS** Required webhook event types (docs): checkout.session.completed, customer.subscription.created, customer.subscription.updated, customer.subscription.deleted, invoice.payment_failed

> Secrets are never printed. Webhook delivery must be proven manually (Stripe CLI or staging).
