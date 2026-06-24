# ArchiveMe — Access Protection Audit

Branch: access-protection-hardening. Audits account access, local app lock, restore access, and anti-sharing guidance **without** adding password login, forcing login before first recording, or enabling RevenueCat.

## Current auth type

| Question | Answer |
| --- | --- |
| Auth provider | **Passwordless email + one-time sign-in code** (`AccountAuth.method = email_code`) |
| Password fields in UI | **No** — `AccountAuthScreen` collects email and code only |
| Raw passwords stored | **No** — `SecureStorageService` rejects password-shaped keys; session is a cookie + last email |
| Firebase password auth | **Not used** |
| Social login | **Not present** |

Relevant files: `lib/auth/account_auth.dart`, `lib/screens/account_auth_screen.dart`, `lib/services/auth_service.dart`, `lib/storage/session_cookie_store.dart`.

Account recovery path: **Resend code** (replaces forgot-password for this provider).

## Local app lock

| Question | Answer |
| --- | --- |
| App lock exists | **Yes** — `AppLockService`, `AppLockGate`, `/security` settings |
| PIN storage | **Salted SHA-256 hash only** — `PinHash` + `AppLockStore` (no raw PIN API) |
| Biometrics | **Optional** — user opt-in; PIN fallback always available |
| Relock behaviour | **~2 minutes** background timeout (`AppLockService.backgroundLockTimeout`) |
| Consumer copy | **Protect this archive** — “This protects the archive on this device.” |
| Overclaim | Does **not** claim to prevent all account or Family Sharing |

Relevant files: `lib/security/app_lock_service.dart`, `lib/security/pin_hash.dart`, `lib/screens/security_settings_screen.dart`, `lib/widgets/security/app_lock_screen.dart`.

## Local archive without login

| Question | Answer |
| --- | --- |
| First recording requires login | **No** — guest-first local mode; `AccountAuthCopy.continueWithoutAccount` on auth screen |
| Auth triggers | Value-based only (`AuthTriggerRules`) — protect archive, sync, export, etc. |
| Sign out deletes local archive | **No** — `AuthService.signOut` clears session cookie only; journal untouched |
| Clear data | User-initiated wipe via Settings / Security privacy controls |

## Restore purchases & Pro

| Question | Answer |
| --- | --- |
| Restore purchases reachable | **Yes** — Settings → Security → Restore purchases; Subscription screen |
| RevenueCat status | **Paused / unavailable** — purchases are unavailable until App Store Connect banking + RevenueCat products configured |
| Pro Preview claims active Pro | **No** — honest unavailable copy + account-restore note for later |
| Purchase-triggered account creation | **Not implemented now** — deferred until purchases enabled |
| Pro purchase auto-creates account | **Not active** while RevenueCat paused |

Pro Preview copy: “Create an account later to restore Pro access when purchases are available.”

## Anti-sharing / unauthorized access

### What the app does today (local-safe)

- **Local app lock** — PIN/biometrics protect archive on this device.
- **Passwordless account** — email-code session for restore/sync when backend configured.
- **Sign out keeps local archive** unless user deletes data.
- **No login wall before recording.**

### What cannot be fully prevented on-device alone

- **App Store Family Sharing** and Apple ID installs are platform-controlled.
- **On-device app sharing** (handing someone an unlocked phone) is not fully preventable without re-lock + user discipline.
- **True Pro anti-sharing** requires **RevenueCat / App Store receipt + stable user identity + server entitlement checks** — not implemented in this branch.

No new server endpoints were added. Existing capture-attest / device registration runs only after sign-in when backend is configured (`GuestFirstAuth.registerDeviceAfterSignIn`).

## Safe to ship for TestFlight now

- Passwordless email-code auth (optional, skippable).
- Local PIN/biometric app lock with hashed PIN storage.
- Honest purchase-unavailable and restore-purchases copy.
- Privacy controls: export, delete local data, hide app-switcher preview.
- No forced login before first saved moment.

## Must wait until RevenueCat / store setup

- Live Pro purchase and purchase-triggered account requirement.
- Server-side entitlement enforcement for anti-sharing.
- Claiming Pro is active or working checkout CTAs.

## Related docs

- [TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md) — physical-device QA including privacy and restore routes
- [STICKY_LOOP_PRODUCT_MAP.md](./STICKY_LOOP_PRODUCT_MAP.md) — product loop (#137)
- `docs/security-hardening-checklist.md` — broader security checklist

## Automated validation

```bash
cd apps/voicememory_mobile
flutter test test/access_protection_hardening_test.dart
```
