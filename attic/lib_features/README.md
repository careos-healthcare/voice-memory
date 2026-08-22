# Deprecated feature modules (attic)

Frozen snapshots of feature directories removed from `apps/mobile/lib/features/` during consolidation.

## belief_change → belief_changes

**Canonical module:** `apps/mobile/lib/features/belief_changes/`

This is the most complete implementation: all 15 files from the four legacy folders, `package:archiveme_mobile` imports, and test-backed refinements (`AppLogger` vs `debugPrint`, const timeline construction).

| Attic path | Files | Tests |
| --- | --- | --- |
| `belief_change/` | change detector, moment engine/gates/copy/analytics/models | `belief_change_detector_test.dart`, `belief_change_moment_test.dart` |
| `belief_evolution/` | evolution models, service, store | `belief_evolution_service_test.dart` |
| `belief_lifecycle/` | lifecycle engine, models, copy | `belief_lifecycle_engine_test.dart` |
| `belief_shift/` | shift engine, models | `belief_shift_engine_test.dart` |

Cross-cutting: `belief_changes_navigation_test.dart`, `belief_changes_temporal_comparison_entry_test.dart`.

Attic copies match git `HEAD` at `apps/voicememory_mobile/lib/features/{name}/`. Diff vs canonical is import-path and style only — no unique logic remains to port.

Do not import from attic in production code.
