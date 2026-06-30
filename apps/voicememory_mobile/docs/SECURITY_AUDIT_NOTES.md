# ArchiveMe / VoiceMemory Mobile — Security & Account-Isolation Audit

**Date:** 2026-06-15  
**Scope:** Authentication state, local data isolation, API access, entitlements, analytics privacy, multi-device behavior.  
**Related:** [ACCESS_PROTECTION_AUDIT.md](./ACCESS_PROTECTION_AUDIT.md)

This note documents current protections, risks, and server-side checks that cannot be fully verified from the mobile repo alone. No secrets or private transcript examples are included.

---

## Executive summary

ArchiveMe is **local-first**: the device is the primary archive boundary. Optional passwordless email auth (`vm_session` cookie) enables sync, export, and server-backed entitlements. **Accounts do not partition local journal data by default** — sign-out intentionally keeps the local archive on device.

**Strengths:** Encrypted journal at rest, secure session cookie storage, app lock (hashed PIN), whitelist-based funnel analytics, HTTPS enforcement in release, capture-token attestation for AI routes.

**Highest risks:** (1) account switch on a shared device can **sync a prior user’s local journal into a new user’s cloud account**; (2) prior user’s recordings remain visible locally to the next user unless wiped; (3) sticky prefs/feedback state is device-global.

**Small fix applied in this audit:** entitlement in-memory + disk cache is cleared on sign-out and before sign-in so Pro state does not bleed across app sessions (`BillingService.resetCachedEntitlementsForAuthChange`).

---

## 1. Authentication state

### Where identity is stored

| Store | Key / field | Contents |
| --- | --- | --- |
| In-memory | `AuthService._cached` | `UserSession` (`userId`, `email`, `signedInAt`) |
| Secure storage | `auth_cookie` via `SessionCookieStore` | `vm_session` HTTP cookie |
| Secure storage | `last_email` | Last email for sign-in prefill (survives sign-out) |

**Files:** `lib/services/auth_service.dart`, `lib/models/session.dart`, `lib/storage/session_cookie_store.dart`, `lib/storage/secure_storage.dart`

### Journal ↔ user association

- `JournalEntry` has **no `userId` field** — entries are device-scoped (`lib/models/journal_entry.dart`).
- Single encrypted journal file per install: `{documents}/journal_entries.enc` (`lib/storage/journal_store.dart`, `lib/services/app_services.dart`).

### Sign-out behavior

`AuthService.signOut()`:

- Calls `POST /api/auth/signout`
- Clears in-memory session and `auth_cookie`
- **Does not** delete journal, prefs, audio, or most feature stores
- **Now clears** entitlement in-memory + `entitlements.json` via `onSignedOut` hook

Documented product intent: local archive stays on device (`AccountAuthCopy.signOutKeepsArchive`, `docs/ACCESS_PROTECTION_AUDIT.md`).

### Different user on same device

There is **no dedicated account-switch flow**. Pattern: sign out → sign in as another user.

| Data | After account switch |
| --- | --- |
| Local journal + transcripts + audio paths | **Retained** — visible to new user in UI |
| `mobile_prefs.json` (feedback, reminders, collections, synthesis cache, etc.) | **Retained** — device-global keys |
| Session cookie | Replaced |
| Entitlement cache | **Cleared on auth change** (this audit) |
| Device ID | **Unchanged** |
| App lock PIN | **Unchanged** |
| RevenueCat customer | **Anonymous/device-scoped** — `logIn`/`logOut` not wired to app auth |

On sign-in, `GuestFirstAuth.registerDeviceAfterSignIn()` runs **`syncNow()`**, which pushes all `localOnly` / `pendingUpload` entries and merges remote entries into the shared local journal — **without checking that local entries belong to the newly signed-in user**.

**Files:** `lib/auth/guest_first_auth.dart`, `lib/services/sync_service.dart`, `lib/storage/journal_store.dart` (`pendingSyncQueue`)

---

## 2. Local data isolation

### Storage map

| Store | Path / backend | Encrypted | User namespaced |
| --- | --- | --- | --- |
| JournalStore | `journal_entries.enc` | **Yes** (AES-256-GCM; key in secure storage) | **No** |
| MobilePrefsStore | `mobile_prefs.json` | No | **No** |
| EntitlementCache | `entitlements.json` | No (billing tier only) | **No** |
| SecureStorageService | flutter_secure_storage | **Yes** | Device-scoped |
| AppLockStore | flutter_secure_storage | **Yes** (PIN hash + salt) | Device-scoped |
| Voice temp files | `vm_rec_*.m4a` / `.wav` | No | **No** |
| CaptureTokenCache | In-memory only | N/A | N/A |
| OfflineDrafts | encrypted journal + `localAudioPath` | Journal **yes**; audio file **no** | **No** |

**Audit helper:** `lib/security/private_storage_audit.dart` (`sensitivePlaintextCount` counts store backends, not individual files).

### Temp voice audio — highest-priority local plaintext risk

Voice capture writes short-lived `vm_rec_*.m4a` files under the system temp directory. They are **not encrypted at rest**.

**Mitigations (2026-06-15):**

1. **After successful save** — when transcription produced usable text (`TempRecordingCleanup.releaseTempAudioIfSafe`), the temp file is deleted and `localAudioPath` is cleared from the journal entry.
2. **On app startup** — `TempRecordingCleanup.purgeStaleOnStartup` removes unreferenced orphans older than one hour and always removes leftover `vm_rec_retry_*` silence-retry files.
3. **Offline / degraded drafts** — when transcription failed or the entry is still a `[draft]`, temp audio is **retained** so the user can retry or type a fallback. This is an intentional, documented temporary plaintext risk until retry completes.

**Files:** `lib/security/private_data_service.dart` (`TempRecordingCleanup`), `lib/services/capture_pipeline_service.dart`, `lib/services/app_services.dart`

### Remaining plaintext stores (audit count unchanged)

`sensitivePlaintextCount` remains **4**: `MobilePrefsStore`, `VoiceRecordings` (mitigated, not encrypted), `CaptureTokenCache` (in-memory), `ArchiveFeatureStores`. Journal text, session/auth, and app-lock data are encrypted in secure storage.

### Feature stores (prefs-backed, device-global)

| Store | Prefs key | File |
| --- | --- | --- |
| Early insight feedback | `earlyArchiveInsightFeedbackRecords` | `lib/features/early_archive/early_archive_insight_feedback_store.dart` |
| Return reminder | `earlyArchiveReturnReminderDismissedAt`, `earlyArchiveReturnReminderSet` | `lib/features/early_archive/early_archive_return_reminder_store.dart` |
| Archive insight feedback | `archive_insight_feedback` | `lib/features/activation/archive_insight_feedback.dart` |
| Archive collections | `archiveCollections` | `lib/features/collections/archive_collection_store.dart` |
| Archive synthesis cache | `archiveMonthlyReviews`, etc. | `lib/features/archive_synthesis/archive_synthesis_store.dart` |

**Partial exception:** synthesis cache keys embed `userId` (or device ID when guest) in sub-keys (`archive_synthesis_hash.dart`), but **prior users’ cached rows are not deleted** on logout.

### Test / demo data mixing

- **Creator demo mode:** sync is blocked; no backend calls (`SyncService.syncNow`, `CreatorDemoMode.isActive`).
- **Sample archive / demo timeline:** labelled sample UI; static demo timelines do not write journal entries (`EarlyEvidenceTimelineDemo`).
- **Risk:** Real journal and demo/sample UI can coexist on device; demo does not auto-clear real data.

### Safe wipe (existing pattern)

User-initiated only — **no automatic delete on logout:**

- Settings → Security → privacy controls → clear local archive (`LocalPrivacyDataControls`, `PrivateDataService.clearLocalArchiveData()`)

---

## 3. Backend / API access

### Client auth model

- **No Bearer tokens.** Session via `Cookie: vm_session=…` on JSON requests (`lib/api/api_client.dart`).
- **Capture attestation:** `x-vm-capture-token` for transcribe/analyze (in-memory token from `POST /api/capture/attest`).
- **Transport:** Release builds reject non-HTTPS / localhost base URLs (`ApiResponseSafety`).

### Authenticated routes (mobile client)

| Area | Endpoints | Auth |
| --- | --- | --- |
| Auth | `/api/auth/send-code`, `/verify`, `/session`, `/signout` | Cookie after verify |
| Journal / sync | `GET/POST /api/journal`, `DELETE /api/journal/:id`, export | Session required (401 → `AuthRequiredException`) |
| Billing | `GET /api/billing/entitlements`, checkout | Session required |
| Archive synthesis | `POST /api/archive-synthesis` | Session required |
| Transcribe / analyze | Multipart + capture token (+ cookie if signed in) | Token and/or session |

**Files:** `lib/api/api_client.dart`, `lib/services/sync_service.dart`, `lib/services/capture_attest_service.dart`

### Server-side checks **not provable from mobile repo alone**

Verify in production / server repo:

1. **Session binding** — `vm_session` validation, expiry, revocation on sign-out and account delete.
2. **Journal authorization** — every journal CRUD scoped to `session.userId`; no IDOR across accounts.
3. **Sync merge policy** — server rejects or tags entries uploaded under a different historical owner if device reuse is a threat model.
4. **Capture token** — one-time JTI, device binding, rate limits (`consumeCaptureAttestation`).
5. **Billing truth** — Stripe/webhook + DB subscription state; `/api/billing/entitlements` matches store receipts.
6. **Archive synthesis tier gate** — server enforces Pro for costly GPT routes (mobile comment suggests client-side Pro check + 403 handling).
7. **OpenAI / usage budgets** — rate limits and kill switches on AI routes.

Sibling server code may exist under the monorepo (`lib/server/api-guard.ts` referenced in prior audits); deployment config still must be verified live.

---

## 4. Entitlements / Pro access

### Resolution order (`BillingService.loadEntitlements`)

1. In-memory `_memory` (unless `forceRefresh`)
2. RevenueCat store entitlements when configured
3. Server `GET /api/billing/entitlements`
4. Disk `entitlements.json` fallback on timeout/error

Merge rule (`mergeEntitlements`): RC Pro wins; when RC configured and free, **stale cached Pro must not win** (tested in `test/launch_hardening_test.dart`, `test/restore_purchases_flow_test.dart`).

### Protections

- UI gates use `ArchiveEntitlementReader` → `billing.loadEntitlements()` (`lib/billing/archive_entitlement_reader.dart`).
- Restore flow calls `loadEntitlements(forceRefresh: true)` after RC restore.
- Auth change now clears cache and refreshes on sign-in.

### Residual risks

| Risk | Severity | Notes |
| --- | --- | --- |
| RC `logIn` / `logOut` not tied to app account | Medium | Pro follows Apple/Google receipt on device, not app email |
| `ArchiveLoopEntitlementStore.isPro` in prefs — write-true-only, never cleared on logout | Medium | Latent if archive-loop billing paths activate |
| `TrialMode` / app-review build flags bypass Pro | Low | Release process must keep flags off |
| Server entitlements when RC unconfigured | Medium | Stale disk cache possible if auth reset skipped |

**RevenueCat purchase/restore logic was not modified** in this audit except cache reset on auth change.

---

## 5. Analytics / privacy

### Primary funnel — `ActivationFunnelAnalytics`

- Typed parameters only; string values must match `^[a-z0-9_]{1,40}$` or whitelisted enums.
- User text, transcripts, and journal bodies are **dropped by design** (`test/activation_funnel_analytics_test.dart`).

### Reviewed events (metadata only)

| Event | Payload | Private text? |
| --- | --- | --- |
| `early_archive_insight_feedback` | `entry_count`, `source`, `stage`, `reason` | No |
| `testflight_feedback_tapped` | `source` (e.g. `settings`) | No |
| `early_archive_return_reminder` | **No analytics emitted** | N/A |
| Paywall / purchase funnel | `source`, `plan`, `reason` ids | No |
| Memory governance | `card_type`, `decision_id`, `reason_id`, counts, bands | No |
| Recording funnel | `entry_count`, `source`, stable ids | No |
| Early archive proof | counts, `stage`, booleans | No |

**Files:** `lib/features/early_archive/early_archive_insight_feedback_analytics.dart`, `lib/features/support/testflight_feedback_analytics.dart`, `lib/features/early_archive/early_archive_proof_analytics.dart`, `lib/services/activation_funnel_analytics.dart`

### Secondary path — `ProductAnalytics`

- Weaker guard (100-char truncation, no whitelist).
- Reviewed string properties are **static catalog prompts** or **canonical theme labels** (not user journal text).
- `topic_label` in early insights infers theme bucket — behavioral metadata, not transcript.

### Not analytics — but sensitive API traffic

Transcripts and journal bodies are sent to backend for transcribe, analyze, journal sync, and archive synthesis by design. That is **processing**, not Firebase telemetry.

---

## 6. Multi-device / double access — expected behavior

| Scenario | Expected behavior (from code) |
| --- | --- |
| Same Apple/Google ID, two devices | Pro via RevenueCat restore on each device; journal syncs if same app account signed in on both |
| Same app account, two devices | Journal sync on sign-in; Pro **not** implied by sign-in alone — purchase/restore per device store account |
| Two people, one physical device | Prior user’s local archive remains after sign-out; app lock helps only while locked; **manual wipe** or clear archive recommended |
| Account switch on one device | New session cookie; local journal + prefs persist; sync may upload prior local entries to new account |
| Offline entries before login | Saved locally (`localOnly` / `pendingUpload`); pushed on next authenticated `syncNow()` |
| Restore purchase on another device | `RestorePurchasesFlow` → RC restore + entitlement refresh |

---

## 7. Current protections (summary)

- Passwordless email OTP; no password storage
- Session cookie in secure storage; sign-out clears cookie
- Journal encrypted at rest; encryption key in secure storage
- Session cookie, device id, and app-lock credentials in secure storage (flutter_secure_storage)
- Optional PIN/biometric app lock (hashed PIN only)
- HTTPS-only API in release builds
- Capture token attestation for AI routes (memory-only token)
- Funnel analytics whitelist — no free-text properties
- Creator demo mode blocks sync
- User-initiated local archive wipe in Security settings
- Entitlement cache cleared on auth change (2026-06-15 fix)
- Temp voice recording cleanup on successful save and startup orphan sweep (2026-06-15)
- Documented access-protection audit for TestFlight

---

## 8. Risks found

### Must-fix before public launch

1. **Cross-account sync on shared device (Critical)** — Sign-in triggers `syncNow()` which uploads all pending/local entries and merges remote data into one device-global journal with no ownership check. A prior user’s recordings can be associated with the next user’s cloud account.  
   **Mitigation direction:** Server-side ownership validation; and/or prompt to wipe / export before account switch; and/or block auto-sync when local entries predate account; and/or attach `ownerUserId` to entries.

2. **Local archive visible after account switch (High — privacy)** — By design for “keep archive on device,” but dangerous on shared phones without wipe + app lock discipline.  
   **Mitigation direction:** Account-switch UX warning; optional “Clear local archive before signing in as someone else.”

3. **Device-global prefs bleed (Medium)** — Insight feedback, return reminder, collections, etc. not cleared on logout.  
   **Mitigation direction:** Namespace prefs by `userId` or clear non-journal prefs on auth change.

### Nice-to-fix after TestFlight

1. Wire RevenueCat `logIn(userId)` / `logOut()` on auth transitions for clearer store↔account binding.
2. Clear or namespace `ArchiveLoopEntitlementStore.isPro` on logout.
3. Rotate or document device ID behavior on account switch.
4. Add integration test: sign out User A (Pro) → sign in User B → Pro gates closed without app restart.
5. Server audit checklist run against staging/production.
6. Tighten `ProductAnalytics` to same whitelist rules as funnel analytics.

---

## 9. Files reviewed

### Auth & session
- `lib/services/auth_service.dart`
- `lib/services/app_services.dart`
- `lib/auth/guest_first_auth.dart`
- `lib/auth/account_auth.dart`
- `lib/screens/account_auth_screen.dart`
- `lib/screens/delete_account_screen.dart`
- `lib/storage/session_cookie_store.dart`
- `lib/storage/secure_storage.dart`

### Local storage
- `lib/storage/journal_store.dart`
- `lib/storage/mobile_prefs_store.dart`
- `lib/storage/entitlement_cache.dart`
- `lib/storage/private_data_encryption_key_store.dart`
- `lib/security/private_storage_audit.dart`
- `lib/security/private_data_service.dart`
- `lib/features/early_archive/early_archive_insight_feedback_store.dart`
- `lib/features/early_archive/early_archive_return_reminder_store.dart`

### API & sync
- `lib/api/api_client.dart`
- `lib/services/sync_service.dart`
- `lib/services/capture_attest_service.dart`

### Billing / entitlements (read-only except cache reset)
- `lib/billing/billing_service.dart`
- `lib/billing/archive_entitlement_reader.dart`
- `lib/billing/revenuecat_service.dart`
- `lib/billing/restore_purchases_flow.dart`

### Analytics
- `lib/services/activation_funnel_analytics.dart`
- `lib/services/product_analytics.dart`
- `lib/features/early_archive/early_archive_insight_feedback_analytics.dart`
- `lib/features/early_archive/early_archive_proof_analytics.dart`
- `lib/features/support/testflight_feedback_analytics.dart`

### Security / access docs & tests
- `docs/ACCESS_PROTECTION_AUDIT.md`
- `lib/security/app_lock_service.dart`
- `test/activation_funnel_analytics_test.dart`
- `test/restore_purchases_flow_test.dart`
- `test/account_auth_test.dart`
- `test/security_auth_isolation_test.dart` (new)

---

## 10. Change log (this audit)

| Change | File | Reason |
| --- | --- | --- |
| Clear entitlement cache on sign-out / before sign-in | `lib/billing/billing_service.dart`, `lib/services/auth_service.dart`, `lib/services/app_services.dart` | Prevent stale Pro across account switch in same app session |
| Temp voice recording cleanup | `lib/security/private_data_service.dart`, `lib/services/capture_pipeline_service.dart`, `lib/services/app_services.dart` | Reduce plaintext temp audio exposure; retain only for offline draft retry |
| Auth isolation unit test | `test/security_auth_isolation_test.dart` | Verify cache reset |
| Temp recording cleanup tests | `test/temp_recording_cleanup_test.dart` | Verify stale purge vs draft retention |
| This document | `docs/SECURITY_AUDIT_NOTES.md` | Audit record |

No changes to RevenueCat purchase, restore, offerings, or paywall purchase flows.
