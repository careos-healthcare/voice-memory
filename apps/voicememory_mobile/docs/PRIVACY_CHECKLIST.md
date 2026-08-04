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
| Push token (Firebase Messaging) | No in focused V1 | No | Remote push is compiled out of V1 startup |
| Purchase status (RevenueCat) | Yes (if billing enabled) | Yes — RevenueCat / App Store | Subscription entitlement |
| Notification permission + reminders | No in focused V1 | No | Not included in the V1 permission envelope |

## 2. Local storage
- Reflections, pattern memory, progress, next action, habit proof, weekly recap,
  first-loop and return-day state, and the reminders-enabled flag are stored
  locally (SharedPreferences-backed store + encrypted journal file).
- **Journal file** (`journal_entries.enc`): AES-256-GCM encrypted; key in
  `flutter_secure_storage`.
- **Mobile prefs** (`mobile_prefs.json`): plaintext JSON — archive metadata and
  cached insights.
- **Retained voice recordings**: AES-GCM encrypted audio vault objects. Plaintext
  exists only during active capture or a short-lived playback/transcription
  lease and is deleted after use.
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
- Provider payloads pass through one content-free catalog immediately before
  dispatch. Only known event ids, known property keys, fixed metadata tokens,
  flags, and coarse count buckets are accepted. Recording/saved text, prompts,
  inferred themes/topics, generated titles/categories, raw ids, email,
  customer/product ids, timestamps, tokens, hashes, nested values, and nulls
  are rejected.
- Invalid payloads fail loudly in debug/test. Release builds drop them and
  increment a local diagnostic counter. Account deletion and local archive
  wipe clear queued events and reset Firebase's installation analytics data.
- Trial activation metrics are stored **locally only** and surfaced in the
  developer/trial control screen for diagnostics; they are not a separate ad/analytics SDK.

## 6. Permissions and reminders
- Focused V1 declares microphone and optional device-authentication access only.
- Microphone access is requested only after the user deliberately starts voice
  recording.
- Device authentication is requested only when enabling or unlocking the
  optional private archive lock.
- Notifications, background scheduling, health, Bluetooth, local network,
  nearby Wi-Fi, location, calendar, activity recognition, camera/photos and
  speech recognition are absent from the focused V1 Release artifact.

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
- **Identifiers** — analytics identifiers in non-trial builds.
- **Diagnostics** — local trial metrics (not exported by an SDK).

Do NOT declare "Data Not Collected" globally — audio and analytics leave the device
in production builds.

## 11. Third parties / SDKs that may receive data
- Firebase (Analytics and Core; Messaging is not initialized in focused V1)
- RevenueCat (if billing enabled)
- Backend host (Vercel-hosted API) for transcription/analysis
