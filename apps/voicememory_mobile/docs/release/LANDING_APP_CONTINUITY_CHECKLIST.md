# Landing ↔ App Continuity Checklist

Internal release checklist so the public website promise matches the in-app experience. Run before App Store / Play Store submissions and after any copy change on either surface.

## Promise alignment

| Surface | Promise | Canonical copy |
| --- | --- | --- |
| Website | 3-day proof challenge | `3-day proof challenge` |
| App (Record) | Day 1 / Day 2 / Day 3 guidance | `Day 1: Save one private moment.` · `Day 2: Come back tomorrow.` · `Day 3: Look for what came back.` |
| Paywall | Keep the longer story | Headline: `Keep the longer story.` · CTA: `Keep my longer story` |
| Pro active | Evidence over time | `Pro is active. ArchiveMe can keep the longer story.` |

## What Pro is (and is not)

- [ ] Pro keeps **more evidence over time** — longer archive history, private monthly reports, pattern and change evidence.
- [ ] Pro is **not more chat** — differentiation line: `Pro is not more chat. It keeps the evidence.`
- [ ] No **therapy**, **diagnosis**, or **treatment** claims anywhere on landing, paywall, or challenge copy.
- [ ] Trust line stays honest: `Private by default. Based on moments you save. Not therapy or medical advice.`

## What we do not promise

- [ ] No **guaranteed transformation** or clinical outcomes.
- [ ] No **cloud backup guarantee** — backup line must stay: `Do not rely on this build as cloud backup.`
- [ ] No **live backup** or “sync is active” / “your archive is backed up” language.
- [ ] No **more AI** positioning on paywall or Pro value surfaces.

## Purchase / restore confidence (app)

- [ ] Initial load: `Checking your Pro access…`
- [ ] Purchase in progress: `Starting secure purchase…`
- [ ] Purchase success: `Pro is active. ArchiveMe can keep the longer story.`
- [ ] Restore in progress: `Checking for previous purchases…`
- [ ] Restore success: `Purchase restored. Pro is active.`
- [ ] Restore empty: `No previous Pro purchase was found on this Apple ID.`

## 3-day challenge (app only)

- [ ] Day 1 body: real moments before ArchiveMe can notice what returns.
- [ ] Day 2 body: coming back gives ArchiveMe something to compare.
- [ ] Day 3 body: same pressure/thought/reaction can start showing the pattern.
- [ ] Completion stays hidden on Record when challenge is complete.
- [ ] No push notifications added for the challenge.
- [ ] Proof thresholds and evidence gates unchanged.

## Verification commands

```bash
cd apps/voicememory_mobile
flutter test test/paywall_purchase_confidence_test.dart
flutter test test/paywall_conversion_clarity_test.dart
flutter test test/three_day_challenge_test.dart
flutter test test/landing_app_continuity_copy_test.dart
```

## Protected areas (do not change in copy-only passes)

- RevenueCat setup, product IDs, entitlements, package lookup
- Purchase and restore logic
- Billing configuration and signing
- Proof thresholds, evidence gates, notification systems
