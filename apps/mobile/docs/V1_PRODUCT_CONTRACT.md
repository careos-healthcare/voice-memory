# V1 Product Contract

**Canonical promise:** A private voice archive that preserves what you actually said and cautiously shows evidence-backed changes over time.

**Machine-readable source:** `lib/core/config/v1_launch_product_contract.dart`

## Nine launch capabilities

| # | Capability | Primary surfaces |
|---|------------|------------------|
| 1 | Fast voice capture | Record tab (`/record`) |
| 2 | Fast text capture | Quick capture (`/quick-capture`) |
| 3 | Reliable private storage | Encrypted journal, account sync |
| 4 | Original transcript archive | Archive tab (`/archive-belief`), entry detail |
| 5 | Search | Archive search field |
| 6 | Cautious verified patterns/changes | Changes tab (`/belief-changes`) |
| 7 | Exact supporting evidence | Belief evidence (`/belief-evidence`) |
| 8 | Correction and suppression | Entry detail, proof correction controls |
| 9 | Optional paid deeper history | Paywall (`/subscription`) |

## Free forever (never paywalled)

- Original transcripts and local archive ownership
- Export (policy-required)
- Correction, suppression, and deletion
- Account security settings

## Pro sells only

- Longer evidence history and continuity on device
- Not weekly reviews, timeline labs, or “more AI”

## Quarantined from production graph

Deferred experiments redirect safely via `lib/router/v1_quarantine_redirects.dart`. They must not appear as route builders, startup services, or launch-visible widgets when `V1FeatureFlags.enableV1Only` is true.

## Trust pillars (first-run)

Shipped on the welcome screen (`OnboardingV1Copy`). Pillar 2 is the send-choice already live in `RemoteProcessingChoiceCopy` / `PrivacyClaimCatalogue` — not on-device AI.

| # | Title | Body |
|---|-------|------|
| 1 | Your words are cited as evidence | Patterns and changes link back to the entries you saved. You can inspect source proof before you rely on any read. |
| 2 | You choose what leaves your phone | Nothing is sent unless you choose a feature that needs it. Choose transcription or sync and your audio and transcript text go to our servers for that job only. Turn it off in Settings → Privacy and new moments stay on this device. |
| 3 | Storage protection is reported live | Your moments stay in local databases on this device. Privacy settings report how this build protects them, instead of asserting it here. |
| 4 | You control all access | Caregiver and observer grants require your explicit consent. Revoke access any time — nothing is shared without your say. |

Archive Home uses the imperative twin of pillar 2: “Choose what leaves your phone” (`RemoteProcessingChoiceCopy.chooseWhatLeavesTitle`). Same choice, not a second claim.

## Trust copy rules

**Avoid:** diagnosis, therapy, certainty, hidden truth, guaranteed transformation, unsupported causality.

**Prefer:** “Your archive noticed…”, “This may be changing…”, “Based on these entries…”, “You can correct or hide this.”

Original customer words must remain visually distinct from generated interpretation on every proof surface.

## Competitive paper trail

Checked 2026-08-30: Revocable, granular caregiver access tied to an evidence ledger has no confirmed competitor as of August 2026, checked against Day One, Rosebud, Mindsera, Reflection, Life Note, CortexOS, Claire, and Stoic.
