# ArchiveMe V1 removal manifest

This is the executable disposition manifest for the shipping graph.
`RETAIN` is required by V1, `CONSOLIDATE` has a temporary extraction
boundary, and `REMOVE` or `EXPERIMENTAL_ISOLATED` modules fail the
architecture guard when transitively imported by the shipping entry point.

## RETAIN

- `apps/voicememory_mobile/lib/api` — present; shipping 10, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/auth` — present; shipping 2, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/billing` — present; shipping 25, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/router` — present; shipping 7, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/security` — present; shipping 20, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/storage` — present; shipping 11, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/recording` — present; shipping 16, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/voice_capture` — present; shipping 22, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/changes` — present; shipping 14, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/explainable_conclusion` — present; shipping 10, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/insight_feedback` — present; shipping 4, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/journal` — present; shipping 5, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/remote_transcription` — present; shipping 2, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/monetization` — present; shipping 7, test-only 0, dormant 0

## CONSOLIDATE

- `apps/voicememory_mobile/lib/services/app_services.dart` — present; shipping 1, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/router/app_router.dart` — present; shipping 1, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/recording/recording_state_controller.dart` — present; shipping 1, test-only 0, dormant 0

## REMOVE

- `apps/voicememory_mobile/lib/features/life_simulator` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/persona_forge` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/autonomous_muse` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/horizon_lab` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/spatial_nexus` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/memory_graph` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/neural_sculptor` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/sandbox_enclave` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/features/apex_profiler` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0

## BACKEND_ONLY

- `app/api/internal` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `app/api/analytics` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `app/api/metrics` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `app/api/resurfacing` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0

## MIGRATION_ONLY

- `apps/voicememory_mobile/lib/features/monetization/data/monetization_local_migration.dart` — present; shipping 1, test-only 0, dormant 0
- `apps/voicememory_mobile/lib/subscriptions/data/legacy_subscription_mapper.dart` — present; shipping 1, test-only 0, dormant 0
- `scripts/activate-monetized-usage-schema.mjs` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `scripts/activate-unit-economics-schema.mjs` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0

## LEGACY_COMPATIBILITY

- None

## EXPERIMENTAL_ISOLATED

- `experiments/archive_me_legacy_flutter` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
- `experiments/archive_me_legacy_web` — empty or non-Dart boundary; shipping 0, test-only 0, dormant 0
