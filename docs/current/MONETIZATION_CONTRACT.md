# ArchiveMe monetization contract

This document is the human-readable index for ArchiveMe monetization. It does
not define a second entitlement policy.

## Authority and change flow

1. The canonical policy source is
   `config/monetization/archive_me_entitlement_matrix.json`.
2. Its shape is constrained by
   `config/monetization/archive_me_entitlement_matrix.schema.json`.
3. `npm run generate:monetization-contract` produces the Dart and TypeScript
   adapters. Generated adapters must never be edited by hand.
4. Mobile and backend enforcement consume those adapters. Documentation,
   release notes, store metadata, support answers, and RevenueCat configuration
   must describe the same policy.
5. CI runs matrix drift, static guards, and documentation-verifier tests via
   `validate:backend-release`. The full `npm run monetization:verify` command
   additionally validates deployment-owned production usage configuration and
   therefore runs in the configured release environment.

If the canonical JSON source is unavailable, do not reconstruct it from this
document. Restore the owning artifact or stop the release.

## Identifiers

- Canonical Pro entitlement: `archive_loop_pro`.
- Accepted legacy entitlement alias: `pro`. It is honoured for existing
  subscribers and is not the canonical id.
- Store product identifiers, on both platforms:
  `com.voicememory.app.pro.monthly` and `com.voicememory.app.pro.annual`.
  These are store product identifiers, not bundle identifiers. Their
  `com.voicememory.app.` prefix is legacy and must never be changed to match the
  application bundle identifier, and the application must never be renamed to
  match them. See `STORE_IDENTITY_CHECKLIST.md`.
- Only `archive_loop_pro_lifetime` may become grandfathered, and only when a
  verified store entitlement names it.

`config/release/archive_me_identity.json` is the authority for all of the above
identifiers.

## Current contract summary

The generated policy names `archive_loop_pro` as the canonical Pro entitlement.
`pro` is accepted only as a legacy entitlement alias.

New purchases use the current RevenueCat offering's monthly and annual package
kinds. A lifetime package must not be offered for new purchase. Only a verified
store entitlement whose product ID appears in the matrix's explicit
`legacyGrandfatheredProductIds` list can become grandfathered; a missing expiry
date alone never grants lifetime access.

Access classes are interpreted as follows:

- `userOwned`: original user content, existing readable output, privacy and
  account controls, and purchase restore/management stay accessible as stated
  by the matrix.
- `freeProof`: the matrix-defined first proof can be generated without Pro and
  must not be consumed from a legacy counter. Local proof generation does not
  depend on RevenueCat or a fabricated remote quota.
- `pro`: new access requires an active Pro entitlement.
- `proMetered`: new access requires Pro and the referenced usage allowance.
- `metered`: access follows the referenced plan allowance.

For the focused V1 return loop this means:

- creating, reading, editing, opening evidence for, correcting, hiding,
  exporting, and deleting original moments remain user-owned access;
- the first valid evidence-backed observation and first valid two-moment
  comparison are free proof and must be shown before a paywall;
- previously generated observations and comparisons remain readable after
  expiry;
- only new ongoing comparison or deeper synthesis generation follows the Pro
  and usage-meter decisions;
- RevenueCat supplies the entitlement snapshot, but never defines these product
  rules.

The policy represents `free`, `trial`, `active`, `gracePeriod`,
`billingIssue`, `expired`, `revoked`, `legacyGrandfathered`, and `unknown`
subscription states explicitly. Trial, active, grace-period, and verified
grandfathered states can authorize new Pro generation; billing-issue, expired,
revoked, and unknown states do not fabricate new Pro access.

The capability rows, expiry behaviour, offline behaviour, copy keys, and meter
bindings are intentionally not copied here. Read them from the canonical matrix
or either generated adapter:

- `lib/monetization/generated/archiveMeMonetizationPolicy.ts`
- `apps/voicememory_mobile/lib/features/monetization/domain/generated/monetization_policy.g.dart`

Some capability rows exist in the matrix without a shipping consumer surface.
`deepArchiveSynthesis` is one of them: the capability id is present, but broad
archive synthesis is a removed product surface and the shipping client makes no
call for it. A matrix row is not evidence that a feature is reachable.

## User-content and expiry guarantees

The matrix requires original-content access and existing generated-output read
access to survive entitlement changes. New Pro or metered generation may stop
after expiry, but expiry must not turn user-owned content into hostage data.
Export, deletion, privacy controls, account deletion, and purchase restoration
must remain reachable according to their matrix rows.

`config/release/archive_me_v1_backend_allowlist.json` records that the shipping
client POSTs to `/api/billing/restore` while no such handler exists in the
backend. Restore therefore cannot be described as working end to end until that
is resolved either by implementing the route or by removing the client call.

## Pricing and unit economics

Storefront prices are not defined in this contract. Consumer UI must use the
localized price returned by the active store offering.

`apps/voicememory_mobile/docs/revenue/PRICING_HYPOTHESES.md` contains research
hypotheses only. It cannot activate a SKU or establish a live price.

Backend-owned cost assumptions and activation instructions live in
`config/unit-economics/` and `docs/UNIT_ECONOMICS_PRODUCTION_ACTIVATION.md`.
They must be validated against current invoices before activation; this
documentation does not duplicate prices, margins, or target metrics.

Production remote allowances are deployment configuration, not constants in
the application. `npm run monetization:verify` fails when
`VOICEMEMORY_USAGE_ALLOWANCES_JSON` is missing or incomplete. Local capture and
all user-owned operations remain available when a remote meter is unavailable.

Usage enforcement persists content-free reserve/commit/release rows with meter,
period, units, provider unit metadata where available, audio seconds, policy
version, a hashed idempotency key, safe result code, and timestamps. Migration
`docs/sql/011_monetized_usage_ledger_metadata.sql` adds that metadata
idempotently.

## Evidence and release status

Repository checks prove consistency, not external completion. RevenueCat,
App Store Connect, Play Console, signed builds, sandbox purchases, restore,
expiry, refund, and physical-device results require dated external evidence.
No purchase, restore or store configuration has been confirmed here; every such
gate is `BLOCKED_EXTERNAL`. Unchecked manual checklists must never be
interpreted as passed:

- `docs/monetization/RELEASE_MANUAL_CHECKLIST.md`
- `docs/monetization/STORE_MANUAL_CHECKLIST.md`
- `docs/monetization/SUPPORT_MANUAL_CHECKLIST.md`
- `docs/monetization/REVENUECAT_MANUAL_CHECKLIST.md`

The launch remains blocked whenever required evidence is missing, stale, or
contradictory.
