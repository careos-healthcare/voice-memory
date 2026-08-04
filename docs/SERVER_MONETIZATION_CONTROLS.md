# Server monetization controls

The backend consumes the generated TypeScript policy derived from
`config/monetization/archive_me_entitlement_matrix.json`. Policy IDs and
entitlement aliases must not be copied into route code.

Production deployment requires:

- durable Postgres storage;
- explicit positive integer burst and daily route limits;
- `VOICEMEMORY_USAGE_ALLOWANCES_JSON` containing every policy plan/meter pair;
- Stripe webhook verification configuration;
- `REVENUECAT_SECRET_API_KEY`; and
- a high-entropy `REVENUECAT_WEBHOOK_AUTH_TOKEN` configured as the RevenueCat
  webhook Authorization header.

There are no production allowance defaults. Missing or malformed allowance
configuration fails the requested remote operation with
`USAGE_ALLOWANCE_CONFIG_INVALID`; local recordings and content remain owned and
available to the client.

Costly routes authenticate the server account, resolve trusted Stripe or
RevenueCat state, select a canonical capability, and reserve usage before any
provider request. Successful provider execution commits actual units where the
provider exposes them. Provider failures release the reservation. Unexpired
reservations count toward the allowance, and Postgres serializes reservations
per account, meter, and billing period.

The ledger stores identifiers, canonical policy IDs, periods, units, state,
timestamps, and a hash of the idempotency key. It contains no prompt,
transcript, quote, audio, image, journal entry, or other user content. Account
deletion removes both entitlement-source and reservation rows.

RevenueCat does not provide a cryptographic webhook signature in this
integration. The webhook is accepted only when its configured high-entropy
Authorization token matches in constant time; it is not represented as a
signed event.
