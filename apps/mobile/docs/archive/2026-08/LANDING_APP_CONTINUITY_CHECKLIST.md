# Landing ↔ App Continuity Checklist

Internal release checklist so the public website promise matches the in-app experience. Run before App Store / Play Store submissions and after any copy change on either surface.

## Promise alignment

| Surface | Promise | Canonical copy |
| --- | --- | --- |
| Website + App | Public promise | `When something repeats, save one real moment. ArchiveMe compares it later.` |
| Website + App | Subheadline | `No daily journal. No streak. No dashboard to maintain.` |
| Website + App | Hero | `When it repeats, save it` |
| Website + App | Hero body | `When something repeats, save one real moment. ArchiveMe compares it later. Not a diary. Not ChatGPT. Not homework.` |
| Website + App | How it works | `Save one real moment` · `Come back when it repeats` · `See what appeared and returned` · `Correct what is not relevant` · `Keep the longer proof trail with Pro` |
| Website + App | ChatGPT differentiation | `ChatGPT can suggest what to do. ArchiveMe shows what you already said before.` |
| App (Record, early) | Step 1 / 2 / 3 guidance | Uses the first three how-it-works steps above |
| Paywall | Keep the longer proof trail | Headline: `Keep the longer proof trail` · CTA: `Keep the longer trail` |
| Paywall | Paid positioning | `Free shows the first useful proof. Pro keeps the longer proof trail.` |
| Pro active | Proof trail continuity | `Pro is active. ArchiveMe keeps the longer proof trail over time.` |

## What Pro is (and is not)

- [ ] Pro keeps **the longer proof trail over time** — what returns, changes, fades, or gets corrected.
- [ ] Pro is **not more chat** — differentiation line: `Pro is not more chat. It keeps the evidence.`
- [ ] No **therapy**, **diagnosis**, or **treatment** claims anywhere on landing, paywall, or early guidance copy.
- [ ] Trust line stays honest: `Private by default. Based on moments you save. Not therapy or medical advice.`

## What we do not promise

- [ ] No **guaranteed transformation** or clinical outcomes.
- [ ] No **cloud backup guarantee** — backup line must stay: `Do not rely on this build as cloud backup.`
- [ ] No **live backup** or “sync is active” / “your archive is backed up” language.
- [ ] No **more AI** positioning on paywall or Pro value surfaces.

## Purchase / restore confidence (app)

- [ ] Initial load: `Checking your Pro access…`
- [ ] Purchase in progress: `Starting secure purchase…`
- [ ] Purchase success: `Pro is active. ArchiveMe keeps the full timeline as it grows.`
- [ ] Restore in progress: `Checking for previous purchases…`
- [ ] Restore success: `Purchase restored. Pro is active.`
- [ ] Restore empty: `No previous Pro purchase was found on this Apple ID.`

## Early record guidance (app only)

- [ ] Step 1 body: save one real moment when something repeats.
- [ ] Step 2 body: come back when it repeats — no daily streak required.
- [ ] Step 3 body: after enough real moments, see the first useful proof.
- [ ] Completion stays hidden on Record when guidance is complete.
- [ ] No push notifications added for early guidance.
- [ ] Proof thresholds and evidence gates unchanged.

## Verification commands

```bash
cd apps/mobile
flutter test test/landing_app_continuity_copy_test.dart
flutter test test/three_day_challenge_test.dart
flutter test test/paywall_copy_alignment_test.dart
flutter test test/paywall_purchase_confidence_test.dart
```

## Protected areas (do not change in copy-only passes)

- RevenueCat setup, product IDs, entitlements, package lookup
- Purchase and restore logic
- Billing configuration and signing
- Proof thresholds, evidence gates, notification systems
