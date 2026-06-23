# Launch validation — ArchiveMe mobile

Focused commands for release readiness. Run from `apps/voicememory_mobile`.

## Release-blocking (focused suite)

```bash
flutter pub get
flutter test \
  test/app_store_rc_polish_test.dart \
  test/mobile_production_readiness_test.dart \
  test/consumer_visible_branding_test.dart \
  test/first_run_payoff_walkthrough_test.dart \
  test/archive_home_priority_test.dart \
  test/next_evidence_plan_test.dart \
  test/archive_watchlist_test.dart \
  test/archive_depth_test.dart \
  test/archive_milestones_test.dart \
  test/shareable_archive_proof_test.dart \
  test/archive_export_pack_test.dart \
  test/launch_hardening_test.dart \
  test/revenuecat_release_config_test.dart \
  test/pro_value_packaging_test.dart
```

Also run from repo root:

```bash
./scripts/validate-mobile-clean-working-tree.sh
```

## iOS release build (no codesign)

```bash
flutter build ios --release --no-codesign 2>&1 | tee /tmp/archiveme_ios_build.log
grep -E "App icon is set to the default placeholder|Launch image is set to the default placeholder|App Icon and Launch Image Assets Validation|error:" /tmp/archiveme_ios_build.log || true
```

When RevenueCat is ready, include dart-defines (see `REVENUECAT_LAUNCH_BLOCKERS.md`).

## Broad analyze / full test caveat

`flutter analyze` and the full `flutter test` suite include legacy surfaces, dev routes, and older widget tests. Some failures may reflect incomplete or internal-only features — **not** all are launch blockers.

Treat as release-blocking only when:

- A focused suite test above fails
- `flutter analyze` reports errors in files touched for launch
- iOS release build fails
- `./scripts/validate-mobile-clean-working-tree.sh` fails

Full-suite noise is documented here so launch validation stays intentional rather than chasing every historical test.

## “Packages have newer versions incompatible”

During `flutter pub get`, Flutter may print that newer package versions exist but are blocked by `pubspec.yaml` constraints. This is informational. **Do not** bulk-upgrade dependencies during launch hardening unless a security or build failure requires it.

## Related docs

- `REVENUECAT_LAUNCH_BLOCKERS.md` — purchases not ready until store setup
- `ROUTE_AUDIT.md` — production vs dev/demo routes
- `docs/REVENUECAT_RELEASE_CHECKLIST.md` — when billing setup resumes
