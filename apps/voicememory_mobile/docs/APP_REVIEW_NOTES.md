# ArchiveMe — App Review Notes (for App Store reviewer)

## What ArchiveMe is
A personal reflection tool. You record one short moment today; tomorrow the app
gives you one simple check about it. Over a few days it shows what kept repeating.

It is **not** a medical or mental-health service and makes no diagnostic claims.

## Release identity (reviewer reference)

- **Public app name:** ArchiveMe
- **iOS bundle ID:** `com.voicememory.mobile`
- **Android application ID:** `com.voicememory.mobile`
- **Deep links:** `archiveme://` (primary), `voicememory://` (legacy compatibility)

## Fastest path: App Review Access (recommended)

This review build includes **App Review Access** in Settings.

1. Open **Settings** (Account tab).
2. Scroll to **App Review Access**.
3. Enter review code: **ARCHIVEME-REVIEW-2026**
4. Tap **Unlock Pro access**.

This loads a **pre-populated sample archive** (repeated patterns, archive proof,
and Pro features) without purchase or account setup.

After unlock, open **Archive** to see patterns and proof from the sample entries.

## Alternative: Sample Archive only

- **Sample Archive:** Settings → Privacy & data → View sample archive, or route `/sample-archive`
- **Help & reviewer guide:** Settings → `/help-reviewer-guide`

Sample Archive uses isolated demo data and never writes to a real journal.

## Reviewing without a backend / account

The full product talks to a backend for transcription and uses an account. For
review convenience, ArchiveMe also ships **local-only trial mode** and
**screenshot mode** (developer builds only).

```bash
# Local-only trial mode (no login / billing / push required)
flutter run --dart-define=ARCHIVEME_TRIAL_MODE=true

# App Review build (includes Settings → App Review Access)
flutter run --dart-define=ARCHIVEME_APP_REVIEW_MODE=true
```

> Trial, screenshot, and App Review modes are **off by default** in normal release
> builds unless the matching `--dart-define` is set at compile time.

## Demo flow (under 1 minute)
1. Unlock App Review Access (above) **or** record one short moment on Record.
2. Open **Archive** to see patterns and proof.
3. On Record, use **Type instead** if microphone is unavailable.
4. **Pro / paywall:** Settings → See Pro preview, or complete the first loop to
   reach the paywall. Subscription details, Terms of Use, and Privacy Policy
   appear on the paywall before purchase.

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
- **Sample Archive:** `/sample-archive` (example data only)
- **Help & reviewer guide:** Settings → `/help-reviewer-guide`
- **Support & feedback:** Settings → `/support-feedback`
- **Pro preview:** Settings → `/pro-preview`
- **Paywall / Pro:** `/subscription`
- **Restore purchases:** Settings → Restore purchases action
- **Privacy / Terms:** Settings → `/privacy` and `/terms`

## Microphone usage
- Used only to record the user's own voice reflections.
- Before the system permission dialog, the Record screen uses **Use voice to record**
  (not Apple-style "Allow" wording).
- Info.plist string: "ArchiveMe needs the microphone to record private voice reflections."

## Known limitations
- Transcription/analysis requires the backend in the full (non-trial) build.
- Some developer/diagnostic screens exist but are gated and hidden from the normal
  participant flow.
- PNG/screenshot export tests are developer tooling and are excluded from the
  routine test run (they are slow/headless-only).
