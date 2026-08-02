# Archive Surprises V1 — plan

## Goal

Surface **evidence-backed** observations that differ from the user’s apparent self-image — not generic coaching copy.

## Examples (target output)

| Pattern | Example |
|---------|---------|
| Dominance gap | You mention Career 63% of the time but rarely mention Relationships (8%, 6 recordings). |
| Theme cessation | You stopped mentioning Confidence concerns in April 2026. |
| Decision loop | You revisit the same decision across 4 weeks (9 recordings). |

## Rules

- **Evidence only** — every row has `evidenceEntryIds` (≥ 3) and `evidenceCount`.
- **No generic observations** — block trait templates (“You focus on…”), theme-loop blind spots, “forming from reflections”.
- **No unsupported claims** — thresholds on eligible count, mention share, and month/week spread.

## Detectors (no new AI)

| Kind | Source |
|------|--------|
| **Theme dominance gap** | `ThemeTrackerService` — top theme ≥ 35% of eligible entries, contrast ≤ 12% and ≤ ⅓ of dominant count |
| **Theme stopped mentioning** | Monthly buckets per canonical theme — prior month peak ≥ 5, last 2 months 0 |
| **Repeated decision loop** | Week buckets — loop phrases / decision keywords in ≥ 3 distinct weeks, ≥ 5 total hits |
| **Stated importance gap** | Same signals as `ArchiveThemeGapEngine` — importance phrase + theme in transcript, share ≤ 12% |

## Module

`apps/voicememory_mobile/lib/features/archive_surprises/`

| File | Role |
|------|------|
| `archive_surprises_models.dart` | `ArchiveSurpriseObservation`, `ArchiveSurprisesView` |
| `archive_surprises_copy.dart` | Observation sentence templates |
| `archive_surprises_engine.dart` | Detectors + ranking (max 4) |

## UI

`lib/widgets/archive_v1/archive_surprises_section.dart` — section title **Surprises**, observation + evidence count.

## Integration

- `ArchiveV1Builder` → `ArchiveSurprisesView` on `ArchiveV1View`
- `ArchiveV1Body` — after Change Feed, before Lifecycle

## Tests

- `test/archive_surprises_engine_test.dart` — unit detectors + generic filter
- `test/archive_surprises_personas_test.dart` — 5 synthetic personas @ 100 reflections

## Reproduce

```bash
cd apps/voicememory_mobile
flutter test test/archive_surprises_engine_test.dart test/archive_surprises_personas_test.dart
```
