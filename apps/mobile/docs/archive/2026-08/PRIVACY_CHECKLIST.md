# ArchiveMe — Privacy Checklist (App Store Nutrition Label Prep)

Be honest. Some data leaves the device (audio is sent to a backend for
transcription/analysis). Do not overclaim "everything stays on device."

Last reviewed: keep this date current at submission time.

---

## 1. Data collected / processed

| Data | Collected | Leaves device? | Purpose |
|------|-----------|----------------|---------|
| Voice recordings | Yes (when you record) | Yes — sent to backend for transcription/analysis | Convert speech to text, generate the next check |
| Transcribed text / reflections | Yes | Stored locally; may be sent to backend for analysis | The core loop (patterns, checks) |
| Pattern / check-in metadata | Yes | Local; trial metrics local only | Drive the daily loop |
| Activation / trial metrics | Yes | Local-only in trial mode | Internal product diagnostics |
| Analytics events (Firebase Analytics) | Yes (non-trial builds) | Yes — Firebase | Product usage analytics |
| Push token (Firebase Messaging) | Yes (non-trial builds) | Yes — Firebase | Remote messaging (separate from local reminders) |
| Purchase status (RevenueCat) | Yes (if billing enabled) | Yes — RevenueCat / App Store | Subscription entitlement |
| Notification permission + reminders | Yes (if enabled) | Local only (local notifications) | Remind you of tomorrow's check |

## 2. Local storage
- Reflections, pattern memory, progress, next action, habit proof, weekly recap,
  first-loop and return-day state, and the reminders-enabled flag are stored
  locally (SharedPreferences-backed store + encrypted journal file).
- **Journal file** (`journal_entries.enc`): AES-256-GCM encrypted; key in
  `flutter_secure_storage`.
- **Mobile prefs** (`mobile_prefs.json`): plaintext JSON — archive metadata and
  cached insights.
- **Temp voice recordings** (`vm_rec_*`): plaintext files under system temp.
- In **trial / local-only mode** there is no cloud sync, billing, push, or login.

## 3. Account / auth status
- Auth is implemented (`flutter_secure_storage`) for the full product.
- The core loop is usable in trial/local mode **without** an account.

## 4. Backend / network
- HTTPS only. App Transport Security `NSAllowsArbitraryLoads = false`.
- Default backend host: `https://voice-memory-iota.vercel.app` (`careosapp.co.uk` is marketing-only).
- Audio + text may be sent there for transcription and analysis.

## 5. Analytics & trial metrics
- Firebase Analytics is used in non-trial builds.
- Trial activation metrics are stored **locally only** and surfaced in the
  developer/trial control screen for diagnostics; they are not a separate ad/analytics SDK.

## 6. Reminders
- Local notifications only (`flutter_local_notifications`), scheduled on-device.
- Permission is requested **only after** the user chooses tomorrow's check, never
  on launch. Reminders fire only when the user enables them in Settings.
- No reminder content is sent off device.

## 7. Purchases / subscriptions
- RevenueCat (`purchases_flutter`) handles subscription entitlement when billing
  is enabled. Disabled / not required in trial mode.

## 8. Export / share behavior
- Users can export reflections and copy/share a plain-text recap (system share
  sheet). Sharing is user-initiated; ArchiveMe does not auto-post anywhere.

## 9. Deletion / reset behavior
- Delete Account flow exists (`/delete-account`).
- Trial reset clears local participant state (see `TrialResetService` and
  `test/trial_reset_full_clear_test.dart`), including reminders.

## 10. App Privacy "nutrition label" notes (App Store Connect)
Likely declarations (confirm against final build):
- **Audio Data** — used for app functionality (transcription). Linked to user if
  account is used.
- **Usage Data** — analytics (Firebase) in non-trial builds.
- **Purchases** — if billing enabled.
- **Identifiers** — push token / analytics identifiers in non-trial builds.
- **Diagnostics** — local trial metrics (not exported by an SDK).

Do NOT declare "Data Not Collected" globally — audio and analytics leave the device
in production builds.

## 11. Third parties / SDKs that may receive data
- Firebase (Analytics, Messaging, Core)
- RevenueCat (if billing enabled)
- Backend host (Vercel-hosted API) for transcription/analysis
