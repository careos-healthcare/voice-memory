# ArchiveMe Security Hardening Checklist

Use this checklist when adding features that touch user journal text, AI calls, or network I/O.

## Prompt injection boundaries

- [ ] All user reflection/transcript text sent to `/api/analyze`, `/api/transcribe`, or archive synthesis is wrapped via `AiPromptBoundary.prepareUserReflectionForApi()`.
- [ ] Wrapped payloads include `USER_REFLECTION_TEXT` delimiters and the untrusted-content instruction.
- [ ] User text never overrides system/developer instructions on the client.
- [ ] Secrets are redacted with `UserContentSafety.redactSecrets()` before any API send.
- [ ] Per-request user text is capped (`AiPromptBoundary.maxUserTextPerRequest`).
- [ ] Logs use `PrivateLog` / `AiPromptBoundary.logSummary()` (length + hash only).

## XSS / plain text rendering

- [ ] Journal entry body, transcript, observation, and exact-language fields render in Flutter `Text` widgets only.
- [ ] No `WebView`, HTML renderer, or markdown-with-HTML for user-authored content.
- [ ] Preview cards use `UserContentSafety.safeSnippet()`.
- [ ] Entry detail may show longer sanitized plain text via `UserContentSafety.sanitizePlainText()`.
- [ ] User content is never passed into routes, URLs, or HTML renderers without sanitization.

## API drain protection

- [ ] Capture/transcription/analysis flows consult `ApiUsageGuard` before expensive calls.
- [ ] Per-entry/capture attempt caps enforced; no infinite retry loops.
- [ ] Cooldown + exponential backoff between retries.
- [ ] Daily local cap for expensive operations.
- [ ] Idempotency key sent on transcribe/analyze when supported (`x-vm-idempotency-key`).
- [ ] Failed transcription settles to degraded state (“Type what you said”), not retry storm.

## Logging privacy

- [ ] No full transcript/body/observation/exact-language text in `print` / `debugPrint` / analytics.
- [ ] Pipeline logs record lengths, presence flags, and hashes only (`RecordPipelineLog`, `PrivateLog`).
- [ ] No auth tokens, capture tokens, entitlement payloads, or API response bodies in logs.

## API base URL safety

- [ ] `VOICE_MEMORY_API_BASE_URL` is `https` in release builds.
- [ ] Localhost / non-HTTPS URLs rejected in release unless explicit debug tools build.
- [ ] `ApiResponseSafety.decodeJsonObject()` used instead of blind `jsonDecode`.
- [ ] HTML responses (`text/html`, `<!DOCTYPE`, `<html`) return safe error: “API base URL returned HTML, expected JSON”.
- [ ] Tokens and API keys are never printed.

## Release build checks

- [ ] `flutter analyze` clean (or only known pre-existing warnings documented).
- [ ] Security tests pass:
  - `test/security_user_content_safety_test.dart`
  - `test/security_api_usage_guard_test.dart`
  - `test/security_prompt_injection_guard_test.dart`
- [ ] Display tests pass (`timeline_entry_display_test.dart`, `post_save_recorded_summary_test.dart`).
- [ ] Manual spot-check: paste `<script>alert(1)</script>` in typed capture — must display as plain text only.

## Private data at rest

- [ ] `PrivateStorageAudit.logAuditReport()` reviewed in debug — journal file is AES-256-GCM encrypted; prefs remain plaintext JSON.
- [ ] Journal encryption key stored in `flutter_secure_storage` via `PrivateDataEncryptionKeyStore` — never in SharedPreferences.
- [ ] Small secrets use `EncryptedPrivateStore` / `flutter_secure_storage` only.
- [ ] Entry delete uses `PrivateDataService.deleteEntrySecurely()` — removes local audio files.
- [ ] Wipe uses typed confirmation (`DELETE MY ARCHIVE`) — clears encrypted journal, drafts, temp audio, insight caches.
- [ ] Export uses `PrivateDataService.buildSanitizedExport()` — no internal ids or audio paths.
- [ ] App lock enabled with 2-minute background re-lock.
- [ ] Emergency wipe available from lock screen without PIN (double confirmation).
- [ ] `Hide ArchiveMe in app switcher` setting obscures snapshots on background.

### Encryption status (honest)

| Data | Encrypted at rest |
|------|-------------------|
| App lock PIN hash / salt | Yes (secure storage) |
| Session cookie / device id | Yes (secure storage) |
| Journal file (`journal_entries.enc`) | Yes (AES-256-GCM) |
| Mobile prefs / archive metadata | No (plaintext JSON) |
| Temp voice recordings (`vm_rec_*`) | No |
| Entitlements cache | No (billing tier only) |

### Consumer privacy copy rules

- [ ] Use `PrivacyCopyPolicy` constants for allowed promises (`privateByDefault`, `nothingSentUnlessChosen`, `exportDeleteAnytime`, `lockArchiveMe`) — do not paraphrase into stronger claims.
- [ ] Do not claim all journal data is encrypted until bulk journal encryption is implemented — **journal file is encrypted; prefs/metadata are not**.
- [ ] Say **private by default**, not **impossible to access**.
- [ ] Say **some features send audio or text for transcription or analysis when used**, not **nothing ever leaves your device**.
- [ ] Say **delete local archive**, not **delete from every server** unless backend delete exists.
- [ ] Avoid **never sent**, **100% secure**, **military grade**, **unhackable**, and **anonymous** in consumer privacy copy unless the feature is truly implemented and scoped.
- [ ] Run `flutter test test/privacy_copy_policy_test.dart` before shipping trust/privacy copy changes.

## Release security CLI

Run before shipping:

```bash
dart run tool/security_release_check.dart
```

Fails on: http production API URL, secret key patterns in client/.env, debug/screenshot defaults, pipeline logging full transcript text, placeholder production URLs.

## Backend required before production

Server-side controls that the mobile client cannot replace:

- [ ] **Auth on every private endpoint** — `/api/journal`, `/api/transcribe`, `/api/analyze`, `/api/sync/*`, `/api/archive-synthesis` require session or capture token; no anonymous access to user data.
- [ ] **Per-user rate limits** — cap transcribe/analyze/archive-synthesis per user per hour/day.
- [ ] **Per-IP rate limits** — throttle abusive clients and credential-stuffing.
- [ ] **Request body size limits** — reject oversized audio/transcript payloads before processing.
- [ ] **Webhook signature verification** — Stripe/RevenueCat webhooks verified server-side; never trust client entitlement alone.
- [ ] **Secrets server-only** — OpenAI, Stripe, RevenueCat secret keys never in mobile `lib/`, `ios/`, or `android/`.
- [ ] **Audit logs privacy** — server logs store entry ids, lengths, and hashes — not full private reflections.
- [ ] **CORS locked down** — allow only production web origins; no `*` on authenticated routes.
- [ ] **JSON errors only** — API returns `application/json` errors; never HTML error pages to the mobile client.
- [ ] **Entitlement validation server-side** — Pro/archive-intelligence gates enforced on server, not client-only.
