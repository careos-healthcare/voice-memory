# Insight-science validators (reactivated)

**Status:** Restored to the active CI pipeline via `npm run validate:insight-science`.

These validators exercise shared theory-tracking, breakthrough, and archive-movement
logic under `lib/` and `packages/shared/`. Mobile Dart theory engines are covered
separately by `apps/mobile/test/archive_*_theory*.dart` and validation suites.

## CI

```bash
npm run validate:insight-science
```

Wired in `.github/workflows/archiveme-stabilization.yml` (server-gates job).

## Mobile theory layer

Enable locally:

```bash
flutter run --dart-define=VOICEMEMORY_ENABLE_THEORY_TRACKING=true
```

Dart tests:

```bash
cd apps/mobile
flutter test test/archive_theory_engine_test.dart \
  test/theory_ranking_engine_test.dart \
  test/archive_agreement_service_test.dart \
  test/archive_primary_theory_validation_test.dart \
  test/archive_quality_validation_test.dart
```
