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

## Reviewing without a backend / account

The full product talks to a backend for transcription and uses an account. For
review convenience, ArchiveMe ships a **local-only trial mode** and a
**screenshot mode** that exercise the core loop with on-device data only (no login,
no billing, no network required for the loop).

Build for review (simulator or device):

```bash
# Local-only trial mode (no login / billing / push required)
flutter run --dart-define=ARCHIVEME_TRIAL_MODE=true

# Or screenshot mode (seeded sample states, good for a quick walkthrough)
flutter run --dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true
```

> Trial and screenshot modes are **off by default** and only turn on when the
> matching `--dart-define` is set, so they cannot ship accidentally in a normal
> release build.

## Demo flow (under 1 minute)
1. Open the app.
2. On Record, see **"Start with one moment"** and record one short moment
   (microphone permission prompt appears the first time).
3. After saving, the app shows the first pattern and offers tomorrow's check.
4. Choose **"Use this tomorrow"** — the app confirms tomorrow's check is set and,
   if you opt in, offers a reminder ("Remind me" / "Not now").
5. On a return day, the due check appears at the top; tap an answer, record one
   short moment, and the loop closes.

If using screenshot mode, you can jump straight to seeded states (see
`docs/SCREENSHOT_CAPTURE_PLAN.md`).

## Login requirements
- None for the trial/local core loop.
- The full product supports an account; it is not required to evaluate the core
  experience.

## Notifications
- Local notifications only. Permission is requested **after** the user chooses
  tomorrow's check (via a soft "Want a reminder tomorrow?" prompt), never on
  launch. Reminders can be toggled in Settings → "Check-in reminders".

## Subscriptions / RevenueCat
- **Purchases are unavailable** until App Store Connect banking and RevenueCat product setup are complete. RevenueCat work is **paused** on this release branch.
- The free archive loop remains usable without Pro.
- **Restore purchases** is available from Settings — expect honest unavailable/inert copy until billing is configured.
- **Pro preview** (Settings → See Pro preview → `/pro-preview`) explains future Pro value only — no live purchase CTA.
- Support: https://careosapp.co.uk/archiveme-support

## Reviewer routes (production build)
- **Record:** `/record` — use **Type instead** if microphone is unavailable
- **Archive Home:** Archive tab → `/archive-belief`
- **Sample Archive:** `/sample-archive` (example data only)
- **Help & reviewer guide:** Settings → `/help-reviewer-guide`
- **Support & feedback:** Settings → `/support-feedback`
- **Pro preview:** Settings → `/pro-preview`
- **Restore purchases:** Settings → Restore purchases action
- **Privacy / Terms:** Settings → `/privacy` and `/terms`

## Microphone usage
- Used only to record the user's own voice reflections. String shown:
  "ArchiveMe needs the microphone to record private voice reflections."

## Known limitations
- Transcription/analysis requires the backend in the full (non-trial) build.
- Some developer/diagnostic screens exist but are gated and hidden from the normal
  participant flow (developer gate + trial mode hides developer surfaces).
- PNG/screenshot export tests are developer tooling and are excluded from the
  routine test run (they are slow/headless-only).
