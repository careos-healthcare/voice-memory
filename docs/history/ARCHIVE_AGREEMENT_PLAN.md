> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Archive Agreement System — plan

## Goal

Let users **Agree**, **Unsure**, or **Disagree** with the archive’s current theory. Responses are **local metadata only** — they do not retrain models or change archive engines.

## Responses

| Value | Meaning |
|-------|---------|
| **Agree** | Theory matches self-image |
| **Unsure** | Partial fit / still forming |
| **Disagree** | Theory does not match |

## Storage

| Key | Format |
|-----|--------|
| `archiveTheoryAgreementHistory` | JSON list of records (newest first), max 50 entries |

Each record:

- `id`, `theoryStatement`, `theoryKey` (normalized hash for matching)
- `response` (`agree` \| `unsure` \| `disagree`)
- `recordedAt` (ISO-8601)
- `confidencePercent` (optional snapshot at time of response)

## Display

1. **Prompt** under theory hero — three buttons; highlights latest response for the **current** theory statement.
2. **Agreement history** — last 12 records with date, response label, truncated theory.

## Module

`apps/voicememory_mobile/lib/features/archive_agreement/`

| File | Role |
|------|------|
| `archive_agreement_models.dart` | Enums + records |
| `archive_agreement_copy.dart` | Strings |
| `archive_agreement_store.dart` | Prefs persistence |
| `archive_agreement_service.dart` | Record + read API |

## UI

`lib/widgets/archive_v1/archive_theory_agreement_section.dart`

## Integration

- `AppServices.archiveAgreement`
- `ArchiveV1Body` — section after theory hero
- No changes to `ArchiveV1Builder`, Theory engine, or Analyst

## Tests

`test/archive_agreement_service_test.dart`

## Reproduce

```bash
cd apps/voicememory_mobile
flutter test test/archive_agreement_service_test.dart
```

