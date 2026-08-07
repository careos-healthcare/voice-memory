# V1 Privacy Boundary

## Account isolation

- Journal, prefs, entitlements, and correction memory are **namespace-scoped** per signed-in account (`AccountNamespace`).
- Account switch rewires stores and reconciles correction scope before reads/writes resume.

## Consent gates

| Data leaving device | Gate |
|---------------------|------|
| Remote transcription / analysis | `RemoteProcessingConsentStore` (fail closed) |
| Encrypted sync payload | User-initiated sync + session auth |
| Store billing | RevenueCat / App Store only |

## What stays on device by default

- Original audio and transcripts
- Correction and suppression choices
- Export files until user shares them

## Startup privacy

- Essential phase: local storage only — no analytics init
- Optional phase: `ProductAnalytics.initialize()` after tabs render
- Startup failure: fixed user copy — never raw exception text

## Permissions (V1)

| Permission | Purpose |
|------------|---------|
| Microphone | Voice capture |
| Biometric (optional) | App lock |
| Internet | Sync + consent-gated remote processing |
| Billing | Optional Pro |

**Disabled in V1:** notifications, speech recognition, health, location, camera, background processing — see `docs/V1_PERMISSION_MATRIX.md`.

## Deletion impact

- Account deletion removes server copy; user offered explicit local wipe separately
- Entry deletion is secure local erase + sync tombstone when configured
