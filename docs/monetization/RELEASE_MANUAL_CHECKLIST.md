# Monetization release manual checklist

Manual evidence only. Every item starts incomplete. Do not mark an item complete
without a dated evidence reference for the exact release candidate.

## Candidate identity

- [ ] Record commit SHA, app version, build number, platform, and test date.
- [ ] Confirm `npm run monetization:verify` passes on that SHA.
- [ ] Confirm generated monetization adapters have no uncommitted drift.
- [ ] Confirm release notes do not claim external setup or purchases are ready
  unless matching evidence is attached.

## Access and expiry

- [ ] Confirm the free proof described by the canonical matrix remains usable.
- [ ] Confirm original entries, saved transcripts, original audio, export,
  correction, hiding, deletion, privacy controls, and account deletion remain
  reachable without Pro where the matrix requires it.
- [ ] Confirm existing generated output remains readable after Pro expires.
- [ ] Confirm expired Pro prevents only new Pro or metered generation described
  by the matrix.
- [ ] Confirm offline behaviour matches each exercised matrix row.

## Transaction evidence

- [ ] Attach the completed iOS physical-device purchase, cancellation, restore,
  expiry/refund/revocation, and offline evidence.
- [ ] Attach the completed Android physical-device purchase, cancellation,
  restore, expiry/refund/revocation, and offline evidence.
- [ ] Confirm a cancelled store sheet does not grant Pro.
- [ ] Confirm stale local state cannot override a verified inactive entitlement.
- [ ] Confirm historical eligible purchasers migrate without exposing a new
  lifetime product.

## Decision

- [ ] Link the authoritative release-readiness record.
- [ ] Record `GO` only when every required external gate has evidence.
- [ ] Otherwise record `BLOCKED` with the missing evidence; do not infer
  completion from automated tests.
