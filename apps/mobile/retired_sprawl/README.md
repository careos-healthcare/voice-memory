# retired_sprawl

Deferred feature modules kept out of the V1 production graph but still referenced by
`lib/` imports (settings, app services, archive widgets, tests, etc.).

## Do analyze and build follow symlinks?

**Yes.** Dart and Flutter resolve `lib/features/<name>/…` through symlinks into this tree.

| Check | Without symlinks | Following symlinks (`find -L`) |
|---|---|---|
| Dart files under `lib/features/` | 187 (13 V1 dirs) | ~2,388 |
| `flutter analyze lib` (Aug 2026) | — | ~7,533 issues |
| `flutter analyze` on 13 V1 dirs only | — | ~260 issues |

Imports from `lib/` and `test/` to symlinked features (Aug 2026): **~2,338** `lib/`
references across **791** files (**270** unique module names in `lib/` alone); **942**
`test/` files also import retired modules (**349** unique names total).

Excluding `retired_sprawl/**` in `analysis_options.yaml` does **not** stop analysis of
symlinked code — the analyzer sees paths as `lib/features/<name>/…`, not
`retired_sprawl/…` — so each symlinked dir is now excluded by its `lib/features/` path
instead. Verified Aug 2026 on Dart 3.12.2: whole-package `flutter analyze` went 10,578 →
5,806 issues, dropping all 4,772 retired diagnostics (1,313 of them errors) while the
5,806 live diagnostics stayed identical, with no new unresolved URIs — excluded
libraries still resolve for live importers, so the exclude is safe **before** the import
count reaches zero.

Excludes never stop **compilation**: retired code reached by a live `import` is still
built into the app, so only the import burn-down (gate condition 1) removes it from the
shipped binary.

Track progress:

```bash
python3 tool/count_retired_feature_imports.py
```

## Deletion gate (replace symlinks with outright removal)

Delete `retired_sprawl/` and stop running `restore_lib_features_symlinks.sh` when
**all** of the following are true:

1. **Zero retired imports** — `python3 tool/count_retired_feature_imports.py` exits 0
   (no `package:archiveme_mobile/features/<X>/…` where `<X>` is outside the 13 V1 dirs).
2. **V1 analyze clean** — `flutter analyze` on the 13 canonical `lib/features/{archive,auth,belief_changes,belief_evidence,capture,fact_ledger,insights,onboarding,quick_capture,record,search,settings,sync}` dirs passes CI thresholds without symlink restore.
3. **One stable release** — at least one TestFlight / Play internal track build promoted
   without a P0/P1 regression traced to a retired module (import path or symlink target).
4. **Date ceiling** — **2026-11-30** — if conditions 1–3 are not met by this date,
   schedule a forced import burn-down; do not extend the symlink bridge indefinitely.

**When the gate passes, delete outright — do not archive.** Retired modules are not
moved to `attic/`, not copied into `docs/archive/`, and not kept "just in case"; git
history is the only archive. Specifically:

- **Who/when** — the release owner checks conditions 1–4 at release cutover, once the
  release is declared stable: one stable release shipped with **zero** regressions
  traced to a retired module.
- **What goes, in one change** — `retired_sprawl/`, the `lib/features/*` symlinks that
  point into it, `tool/restore_lib_features_symlinks.sh`, and the matching
  `lib/features/*` entries under `analyzer: exclude:` in `analysis_options.yaml`.
- **If a regression is traced to a retired module** — the clock resets; re-check at the
  next stable release rather than deleting on schedule.

Until the gate passes, symlinks remain a **compile/test bridge**, not part of the V1
product surface.

## Restoring compile/test resolution

After a clean checkout, run:

```bash
./tool/restore_lib_features_symlinks.sh
```

That script:

1. Symlinks missing `lib/features/<name>` dirs to `retired_sprawl/lib_features/<name>`
2. Merges retired onboarding files into `lib/features/onboarding/` (preserves `ui/`)
3. Merges retired insights files into `lib/features/insights/` (preserves V1
   `archive_insight.dart` and `insight_evidence.dart`)

## V1-local overrides

These dirs are **not** fully replaced by symlinks:

| Path | Reason |
|------|--------|
| `lib/features/onboarding/ui/` | V1 onboarding copy + trust pillars |
| `lib/features/auth/` | Multi-party access + consent revocation |
| `lib/features/insights/archive_insight.dart` | V1 insight model + `ArchiveInsightsSnapshot` |
| `lib/features/insights/insight_evidence.dart` | Re-exports belief evidence lines |
| `lib/features/belief_changes/` | Canonical belief change module |
| `lib/features/belief_evidence/` | Evidence trust pillar UI |

Long term, imports should be trimmed so only V1 modules remain in `lib/features/`.
