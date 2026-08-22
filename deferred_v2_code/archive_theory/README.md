# Deferred v2 — Archive theory / insight-science layer

**Status:** Reactivated into `apps/mobile/` behind `VOICEMEMORY_ENABLE_THEORY_TRACKING` (default off).

Canonical active paths (not `voicememory_mobile`):

| Path | Purpose |
| --- | --- |
| `apps/mobile/lib/features/archive_theory/` | `ArchiveTheoryEngine`, `TheoryRankingEngine`, models, copy |
| `apps/mobile/lib/features/archive_agreement/` | Theory agreement capture (agree / unsure / disagree) |
| `apps/mobile/lib/widgets/archive_v1/` | Theory hero card, agreement section, `ArchiveV1Body` |
| `apps/mobile/lib/features/archive_intelligence/` | `ArchiveIntelligencePresentation` gate for archive tab |
| `apps/mobile/test/` | Theory engine, ranking, agreement, and validation tests |

Registered in `apps/mobile/tool/v1_registered_feature_modules.txt` as `archive_theory` and `archive_agreement`.

## Enable locally

```bash
flutter run --dart-define=VOICEMEMORY_ENABLE_THEORY_TRACKING=true
```

## Validation

```bash
npm run validate:insight-science
cd apps/mobile && flutter test test/archive_theory_engine_test.dart test/theory_ranking_engine_test.dart test/archive_agreement_service_test.dart test/archive_primary_theory_validation_test.dart test/archive_quality_validation_test.dart
```

This folder retains historical copies for reference; active code lives under `apps/mobile/`.
