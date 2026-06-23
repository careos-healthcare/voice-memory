# App Store submission pack — ArchiveMe

**Status:** Preparation only — App Store submission is **not complete**. Purchases are **unavailable** until RevenueCat and store setup finish.

## App identity

| Field | Value |
|-------|-------|
| App name | **ArchiveMe** |
| Support URL | https://careosapp.co.uk/archiveme-support |
| Bundle ID | `com.voicememory.app` (technical — do not use in consumer copy) |

## Current product status

- **Free archive flow:** Usable — record or type moments, view Archive Home, Sample Archive, evidence tools.
- **Purchases / subscriptions:** **Not live** — RevenueCat requires banking/store setup; paywall shows *“Purchases are not available right now.”*
- **Do not claim** subscriptions can be purchased in App Store metadata until sandbox evidence is complete.

## Reviewer path (recommended)

1. Open app (Record tab is the default).
2. Tap **Type instead** if microphone access is unavailable or preferred.
3. Save **one moment** (typed or voice).
4. Open **Archive** (Patterns tab).
5. Open **Sample Archive** for a full demo with example data only — nothing writes to the real journal.
6. Open **Evidence Map** from Sample Archive or Archive Home (when enough demo/sample context exists).
7. Open **Help & reviewer guide** (Settings).
8. Open **Support & feedback** (Settings).
9. Open **Pro Preview** — value preview only; **purchases are not live yet**.

## Privacy (for reviewers)

- Archive stays **local to this device** unless the user explicitly exports or shares.
- **Share-safe proof** and export paths do not include raw private entries by default.
- **Sample Archive** uses example data only — no real user content.
- ArchiveMe is not therapy, medical advice, or emergency support.
- Beliefs shown in the archive are **cautious** and **not conclusions**.

## Screenshot checklist

Capture from **Sample Archive** or a clean test account where possible. See `APP_STORE_SCREENSHOT_CAPTIONS.md` for caption text.

- [ ] Record / Type instead — first moment
- [ ] Archive Home — summary after save
- [ ] Archive Home — smart layout with priority cards
- [ ] Evidence Map (sample or 3+ moments)
- [ ] Next Evidence Plan / Watchlist (when visible)
- [ ] Sample Archive banner and tour
- [ ] Export / share-safe proof (review-before-share line visible)
- [ ] Settings — Privacy & data controls
- [ ] Help & reviewer guide
- [ ] Pro Preview (no purchase CTAs in frame)

Use light mode, ArchiveMe branding only, no debug overlays.

## Manual QA checklist

See `MANUAL_WALKTHROUGH_CHECKLIST.md` for step-by-step paths.

- [ ] Fresh install → onboarding → Record
- [ ] Microphone denied → Type instead works
- [ ] First save → Archive Home payoff
- [ ] Second / third entry → comparison / cautious belief copy
- [ ] Sample Archive → no journal writes
- [ ] Export → review-before-share
- [ ] Restore purchases → unavailable message (expected until RC live)
- [ ] Pro Preview → preview only, no purchase completion
- [ ] Offline / backend unavailable → local save still works where designed
- [ ] Privacy & data controls reachable

## Related docs

- `APP_STORE_SCREENSHOT_CAPTIONS.md`
- `MANUAL_WALKTHROUGH_CHECKLIST.md`
- `REVENUECAT_LAUNCH_BLOCKERS.md`
- `LAUNCH_VALIDATION.md`
- `lib/features/submission/app_store_submission_copy.dart` (in-app reviewer notes source)
