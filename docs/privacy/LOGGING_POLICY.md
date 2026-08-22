# Logging policy (focused beta)

**Scope:** Mobile production graph (Record, Archive, Account, consent, export, deletion, optional sync/billing) and active server API routes.

## Principles

1. **Structured events only** — use `ReleaseLogger` with `event`, `severity`, `category`, and coarse operational fields.
2. **No correlatable content surrogates** — do not log hashes, fingerprints, or stable identifiers derived from user content.
3. **Release builds are strict** — debug-only detail (`ReleaseLogger.debugDetail`) is stripped in release; raw `debugPrint` of paths, IDs, or exceptions is forbidden on production paths.
4. **Exceptions map to categories** — log `error_code` (controlled token), never raw `exception=` or thrown message text in release.

## Allowed fields (release)

| Field | Example | Notes |
|-------|---------|-------|
| `event` | `transcription_failed` | snake_case, stable |
| `severity` | `error` | debug / info / warn / error |
| `category` | `transcription` | capture, sync, auth, export, … |
| `error_code` | `offline` | mapped from failure; never raw exception text |
| `success` | `true` | bool |
| `http_status` | `503` | int |
| `duration_bucket` | `lt_1s` | coarse timing |
| `bytes_bucket` | `lt_256kb` | audio/file size class |
| `*_length_bucket` | `lt_2048` | counts only, never content |
| `mode`, `operation`, `status` | `native_file_stt` | enum-like tokens |
| `present`, `shown`, `blocked`, `missing` | `true` | booleans |

## Prohibited in release logs

- Transcripts, typed moments, correction notes, insight bodies, widget title/body
- Local file paths (`/var/...`, `.m4a`, `/tmp/`)
- Entry/archive/proof/evidence IDs
- Content hashes or fingerprints
- Auth/session tokens, API keys, webhook secrets
- Email addresses
- Request/response bodies, provider payloads
- Raw exception messages or stack traces

## Examples

**Allowed (release):**
```
ARCHIVEME_LOG event=transcription_failed severity=error category=transcription success=false error_code=offline
ARCHIVEME_LOG event=capture_saved severity=info category=capture success=true display_text_length_bucket=lt_256
ARCHIVEME_LOG event=sync_push_failed severity=error category=sync success=false error_code=offline http_status=503
```

**Prohibited:**
```
ARCHIVEME_TRANSCRIPTION_STARTED audioPath=/var/mobile/Containers/.../capture.m4a
ARCHIVEME_RECORD_PIPELINE: saved entry id=entry-7f3a...
Auth: verify failed — INVALID_CODE: Code expired for user@example.com
hash=abc123def...
```

## Retention

- Device logs: ephemeral OS log buffer only; no server upload of debug console output in beta.
- Analytics: separate `ProofAnalyticsGuard` allowlist (structural keys only).
- Server structured logs: sanitized via `packages/shared/lib/server/log-sanitizer.ts`.

## Enforcement

- Mobile: `dart run tool/validate_mobile_privacy_logs.dart`
- Repo: `npm run validate:privacy-logs`
- Tests: `flutter test test/security/release_logger_test.dart`
