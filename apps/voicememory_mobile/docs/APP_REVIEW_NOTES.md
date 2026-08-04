# ArchiveMe — App Review Notes (for App Store reviewer)

## What ArchiveMe is
**Category:** Auditable personal change.

**Promise:** “See what repeated. See what changed. Verify it in your own words.”

**In full:** A private change ledger that shows exactly what repeated, what
changed, the words proving it, and lets you correct the record.

AI is used for transcription and for drafting each observation. That is a
processing detail, not the product: nothing is presented without the exact saved
words and dates behind it.

It is **not** a medical or mental-health service, **not** a companion or chat
product, and makes no diagnostic, personality, or hidden-truth claims.

## Release identity (reviewer reference)

- **Public app name:** ArchiveMe
- **iOS bundle ID:** `com.voicememory.mobile`
- **Android application ID:** `com.voicememory.mobile`
- **Release deep link:** `archiveme://`

## Review flow

1. Open Record and choose **Type instead** if microphone capture is inconvenient.
2. Save a real sentence. The receipt shows Saved, the editable transcript, and
   at most one validated “Possible read”.
3. Open the exact source moment from the evidence receipt and try Accurate,
   Wrong angle, Too generic, or Hide.
4. Save a second related but different moment, then open Changes. A defensible
   comparison shows exact Then/Now words and dates; unrelated moments correctly
   show no comparison.
5. Open Account for privacy, export, deletion, subscription, restore, terms,
   and support controls.

## Reviewing without a backend / account

The full product talks to a backend for transcription and uses an account. For
review convenience, ArchiveMe also ships **local-only trial mode** and
**screenshot mode** (developer builds only).

```bash
# Local-only trial mode (no login / billing / push required)
flutter run --dart-define=ARCHIVEME_TRIAL_MODE=true

# App Review build (includes Settings → App Review Access)
flutter run --dart-define=ARCHIVEME_APP_REVIEW_MODE=true

# Or use the helper script:
./tool/run_app_review_mode.sh
```

In that review build, open Settings → App Review Access and enter
`ARCHIVEME-REVIEW-2026`. The review flow then loads the pre-populated sample archive.
This access path is disabled in ordinary production builds unless App Review
mode was explicitly enabled at compile time.

> Trial, screenshot, and App Review modes are **off by default** in normal release
> builds unless the matching `--dart-define` is set at compile time.

## Demo flow (under 1 minute)
1. Record or type one short moment.
2. Review and optionally edit the transcript.
3. Inspect the exact evidence behind the cautious observation, if one is
   reliable enough to show.
4. Return with a related moment and open **Changes** for an auditable Then/Now
   comparison.
5. Open Account → Subscription to review purchase and restore UI. No paywall is
   shown before the free proof.

## Login requirements
- None for App Review Access, Sample Archive, or the trial/local core loop.
- The full product supports an account; it is not required to evaluate core
  features when using App Review Access.

## Notifications
- Local notifications only. Permission is requested **after** the user chooses
  tomorrow's check (via a soft reminder prompt), never on launch. Reminders can
  be toggled in Settings → "Check-in reminders".

## Subscriptions / ArchiveMe Pro
- **ArchiveMe Pro** — monthly or yearly auto-renewing subscription.
- Prices appear on the paywall when App Store products load; otherwise the paywall
  states that plans will appear once products load.
- **Terms of Use:** https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- **Privacy Policy:** https://careosapp.co.uk/archiveme-privacy
- **Restore purchases** is available from Settings.
- Support: https://careosapp.co.uk/archiveme-support

## Reviewer routes (production build)
- **Record:** `/record` — use **Type instead** if microphone is unavailable
- **Archive Home:** Archive tab → `/archive-belief`
- **Changes:** Changes tab → `/belief-changes`
- **Account:** `/account`
- **Support & feedback:** Account → `/support-feedback`
- **Paywall / Pro:** Account → `/subscription`
- **Restore purchases:** Account → `/restore-purchases`
- **Privacy / Terms:** Account → `/privacy` and `/terms`

## Microphone usage
- Used only to record the user's own voice reflections.
- Before the system permission dialog, the Record screen uses **Use voice to record**
  (not Apple-style "Allow" wording).
- `Info-Release.plist` string: "ArchiveMe uses the microphone when you choose
  to record a private journal moment."

## Known limitations
- Transcription/analysis requires the backend in the full (non-trial) build.
- PNG/screenshot export tests are developer tooling and are excluded from the
  routine test run (they are slow/headless-only).
