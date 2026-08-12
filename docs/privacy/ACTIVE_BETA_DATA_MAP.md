# Active beta data map

**Date:** 2026-08-12  
**Scope:** Production graph reachable from Record, Archive, Changes, Account, consent, export, deletion, app lock, and optional sync (`V1ProductionAllowlist`, `FOCUSED_BETA_DECISIONS.md`).

Legend — **Sensitivity:** `public` | `operational` | `personal` | `credential`  
**Encryption:** `none` (metadata-only prefs) | `encrypted` (journal AES-GCM envelope or encrypted prefs blob) | `secure_enclave` (key material only)

---

## Journal and capture

| Field / category | Example shape (never real user data) | Sensitivity | Local store | Encryption | Remote | Retention / deletion | Export | Owner |
|------------------|--------------------------------------|-------------|-------------|------------|--------|-------------------|--------|-------|
| Voice moment transcript + reflection | `{ "transcript": "…", "reflection": {…} }` | personal | `JournalStore` (`journal_entries.json` / `.enc`) | encrypted | Optional sync ciphertext only | Entry delete; local wipe via `PrivateDataService` | Yes (sanitized text fields) | User |
| Local audio path (device) | `{ "localAudioPath": "/…/vm_rec_….m4a" }` | operational | Journal entry field | encrypted with journal | Never path-only upload in beta decline path | Deleted with entry / temp cleanup | No (paths stripped) | User |
| Capture token | `{ "token": "…", "expiresInSeconds": 3600 }` | credential | `CaptureTokenCache` (memory + short-lived) | none in RAM | Attest endpoint when consented | Cleared after successful capture | No | Session |

---

## Remote processing consent

| Field / category | Example shape | Sensitivity | Local store | Encryption | Remote | Retention / deletion | Export | Owner |
|------------------|---------------|-------------|-------------|------------|--------|-------------------|--------|-------|
| Granted purposes | `{ "grantedPurposes": ["remote_transcription","remote_reflection"], "policyVersion": 2 }` | operational | `MobilePrefsStore` key `remote_processing_consent_v1` | none | None until consented network call | Withdraw clears purposes; namespace wipe | No | User |
| Consent timestamps | `{ "consentedAt": "2026-08-12T…Z", "revokedAt": null }` | operational | same | none | — | Preserved in history fields on withdraw | No | User |

---

## Archive insight feedback (beta)

| Field / category | Example shape | Sensitivity | Local store | Encryption | Remote | Retention / deletion | Export | Owner |
|------------------|---------------|-------------|-------------|------------|--------|-------------------|--------|-------|
| Feels-right / not-quite counts | `{ "feelsRight": { "beliefUpdate": 2 } }` | operational | `MobilePrefsStore` `archive_insight_feedback` | none | Never | `ArchiveInsightFeedbackStore.clearAll`; local wipe | No | User |
| Hidden insight ids | `{ "hidden": ["weeklyReview"] }` | operational | same | none | Never | same | No | User |
| **Correction notes (free text)** | `{ "notes": { "beliefUpdate": "Not about work…" } }` | **personal** | `MobilePrefsStore` opaque key `secure_archive_insight_correction_notes_v1` | **encrypted** (journal namespace key) | Never | Encrypted blob clear on wipe | **Yes** (`insightCorrectionNotes` in export JSON) | User |
| Early archive feedback choice | `{ "insightType": "timeline", "value": "feelsRight" }` | operational | `earlyArchiveInsightFeedbackRecords` | none | Never | Store reset / wipe | No | User |

---

## Corrections and pattern naming (beta)

| Field / category | Example shape | Sensitivity | Local store | Encryption | Remote | Retention / deletion | Export | Owner |
|------------------|---------------|-------------|-------------|------------|--------|-------------------|--------|-------|
| Canonical archive corrections | `{ "choice": "partlyRight", "targetProofId": "…" }` (no free text) | operational | `canonical_archive_corrections_v1` | none | Never | `ArchiveCorrectionStore.clearAll` | Structural only via correction export paths | User |
| Pattern confirm keys | `{ "confirmed": ["said_yes_when_tired"] }` | operational | `pattern_name_preferences_v1` | none | Never | `PatternNameStore.clearAll` | No | User |
| **Custom pattern names** | `{ "renamed": { "said_yes": "Agreeing when tired" } }` | **personal** | `secure_pattern_custom_names_v1` | **encrypted** | Never | Encrypted blob clear | Included when pattern export surfaces read store | User |

---

## Account, security, sync

| Field / category | Example shape | Sensitivity | Local store | Encryption | Remote | Retention / deletion | Export | Owner |
|------------------|---------------|-------------|-------------|------------|--------|-------------------|--------|-------|
| Onboarding completed | `{ "onboardingCompleted": true }` | operational | `MobilePrefsStore` | none | — | Namespace wipe | No | User |
| App lock / biometrics prefs | `{ "biometricLockEnabled": true }` | operational | User settings / secure prefs | mixed | — | Settings / wipe | No | User |
| Sync master key | base64 key bytes | credential | `SecureSyncMasterKeyStore` | secure_enclave | Sync when enabled | Account deletion flow | No | User |
| Encrypted sync journal blob | ciphertext envelope | personal | Server + local coordinator | encrypted | Optional | Account deletion + local wipe | User-initiated export only | User |

---

## Out of scope (listed, not migrated in Command 02)

| Finding | Location | Why out of scope |
|---------|----------|------------------|
| Archive feedback free-text items | `archiveFeedback` prefs | Support / labs surface; not on V1 tab graph |
| Beta feedback intelligence | `beta_feedback_intelligence` | Quarantined widget |
| Curiosity loop plaintext legacy | various `curiosity_*` keys | Clinical sandbox / quarantined under V1-only |
| Cognitive baseline / trajectory | encrypted clinical telemetry keys | Internal telemetry; separate key from journal |
| Home screen widgets | native shared preferences | **Excluded** in focused beta (`enableWidgets => false`) |
| Theory / blind-spot reaction strings | `blindSpotReactions`, `theoryNotifications` | Off production graph |

---

## Policy rules (enforced)

1. `MobilePrefsStore` holds only non-sensitive booleans, counters, coarse timestamps, schema versions, opaque encrypted blobs, and non-content identifiers.
2. Personal free text uses `PersonalContentEncryptedStorage` (journal namespace key) via `SensitivePrefsEncryptedBlob`.
3. Legacy plaintext migration is idempotent: encrypt → verify → delete plaintext field.
4. Saves await durable disk writes before reporting success for correction notes and custom pattern names.
