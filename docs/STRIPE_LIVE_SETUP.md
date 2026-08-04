# Stripe live integration

ArchiveMe uses **Stripe Checkout** (subscription mode) and a **signed webhook** to grant Pro entitlements server-side. Billing is **fail-closed** when any required env var is missing.

## Required environment variables

| Variable | Where | Notes |
|----------|--------|--------|
| `STRIPE_SECRET_KEY` | Server only | `sk_live_…` in production; `sk_test_…` in staging |
| `STRIPE_WEBHOOK_SECRET` | Server only | From Stripe Dashboard → Webhooks → signing secret (`whsec_…`) |
| `STRIPE_PRO_PRICE_ID` | Server only | e.g. `price_…` — **never** use `NEXT_PUBLIC_*` |
| `NEXT_PUBLIC_APP_URL` | Public | HTTPS origin for success/cancel URLs |

Optional after manual webhook test:

- `STRIPE_WEBHOOK_LIVE_PROOF=1` — documents that webhook delivery was verified in staging/production

## Stripe Dashboard setup

### 1. Product and price

1. **Products** → create **ArchiveMe Pro** (recurring).
2. Add a monthly price (displayed from Stripe via STRIPE_PRO_PRICE_ID, fallback £9.99/month).
3. Copy the **Price ID** → `STRIPE_PRO_PRICE_ID`.

### 2. Webhook endpoint

**Developers → Webhooks → Add endpoint**

- **URL:** `https://<your-domain>/api/billing/webhook`
- **Events to send** (minimum):
  - `checkout.session.completed`
  - `customer.subscription.created`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
  - `invoice.payment_failed`

Copy the **Signing secret** → `STRIPE_WEBHOOK_SECRET`.

Apply the entitlement schema migration before enabling checkout:

```bash
psql "$DATABASE_URL" -f docs/sql/007_stripe_subscription_end_date.sql
```

### 3. Customer metadata

Checkout sets `metadata.userId` and `client_reference_id` to the signed-in user id so webhooks can map subscriptions to entitlements.

## Entitlement lifecycle (server)

| Event | Effect |
|-------|--------|
| `checkout.session.completed` | Retrieve subscription → **pro** if active/trialing |
| `customer.subscription.created` / `updated` | **pro** if active/trialing; **free** if canceled/unpaid |
| `invoice.payment_failed` | **free** tier, `past_due` status (no pro grant) |
| `customer.subscription.deleted` | Revoke pro (free tier) |

Duplicate webhook deliveries are ignored via `stripe_webhook_events` idempotency table.

## Local testing with Stripe CLI

```bash
# Install: https://stripe.com/docs/stripe-cli
stripe login

# Forward webhooks to local Next.js
stripe listen --forward-to localhost:3000/api/billing/webhook

# Copy the whsec_… from listen output into .env.local:
# STRIPE_WEBHOOK_SECRET=whsec_...

# Trigger test events
stripe trigger checkout.session.completed
stripe trigger customer.subscription.updated
stripe trigger invoice.payment_failed
```

Use **test mode** keys (`sk_test_…`, test price id) in `.env.local`. Run checkout from the app while signed in.

## Flutter web-checkout switch

Native RevenueCat billing remains the default. Build with the global switch
plus the relevant channel permission only after confirming that the app's
storefront, distribution method, and review terms permit an external purchase
link:

```bash
# Android example for an eligible distribution channel
flutter run \
  --dart-define=USE_WEB_STRIPE_CHECKOUT=true \
  --dart-define=ALLOW_ANDROID_WEB_STRIPE_CHECKOUT=true

# iOS: do not enable without an applicable entitlement or storefront rule
flutter run \
  --dart-define=USE_WEB_STRIPE_CHECKOUT=true \
  --dart-define=ALLOW_IOS_WEB_STRIPE_CHECKOUT=true
```

When enabled, the record entry point checks
`GET /api/user/subscription-status`, inactive users are routed to the native
paywall, and **Upgrade on Web** requests an authenticated Checkout Session from
`POST /api/billing/checkout`. Cloud attest/transcription is skipped for
inactive users and the recording is retained locally.

## Validation commands

```bash
# Code + env presence (no secrets printed)
npm run validate:stripe-live

# Also verify price exists in Stripe (needs valid keys)
npm run validate:stripe-live -- --retrieve-price

# Full billing unit tests (mocked + structural)
npm run validate:billing

# After manual webhook test in staging:
export STRIPE_WEBHOOK_LIVE_PROOF=1
npm run validate:stripe-live
```

## Manual proof checklist

See `~/Desktop/spp20/stripe_live_integration_checklist.md` for the step-by-step staging proof (checkout → pro → cancel → free).

## Security notes

- Webhook body is verified with `stripe.webhooks.constructEvent` and `STRIPE_WEBHOOK_SECRET`.
- Price ID is only read in `lib/billing/stripe-config.ts` and checkout API route.
- Client calls `POST /api/billing/checkout` and redirects to Stripe-hosted URL — no secrets in the browser.
