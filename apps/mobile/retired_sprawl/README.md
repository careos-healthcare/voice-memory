# retired_sprawl

## Deletion date

> DELETION DATE: October 22, 2026. This directory and all its contents must be permanently deleted on or before this date, provided no regressions have been traced to it.

That is the headline, and it is a commitment to finish work, not a documentation
change. **The date is the deadline for completing the import burn-down**, not a
licence to delete on schedule regardless of state. The four-condition
[deletion gate](#deletion-gate-replace-symlinks-with-outright-removal) below —
zero retired imports, clean V1 analyze, one stable release, date ceiling — states
**prerequisites, not alternatives**. Removing the directory while
`lib/features/*` symlinks are still imported breaks the build outright; the
"no regressions traced to it" proviso in the headline is necessary but nowhere
near sufficient.

Deferred feature modules kept out of the V1 production graph but still referenced by
`lib/` imports (settings, app services, archive widgets, tests, etc.).

## Unresolved conflicts

Both conflicts below are open. Neither is resolved by this document; both need a
scheduling decision from the release owner.

### Conflict A — the burn-down ceiling is five weeks *after* the deletion date

Gate condition 4 sets a date ceiling of **2026-11-30** for forcing the import
burn-down. The deletion date above is **2026-10-22**, five weeks earlier. As
written the sequence is incoherent: the burn-down that must precede deletion is
scheduled to complete after the deletion it gates.

**Resolved: the ceiling is now 2026-09-30.** It has to sit far enough before
2026-10-22 to leave room for conditions 2 and 3 (V1 analyze clean, one stable
release shipped and declared stable) to complete between the burn-down finishing
and the directory being removed. A TestFlight / Play internal promotion plus a
stability soak is realistically two to three weeks, which puts the ceiling at
the end of September.

### Conflict B — a hard date is a commitment to real, unfinished work

`lib/features/` holds **373 symlinks** into `retired_sprawl/lib_features/` (387
entries in total; the other 14 are real V1 directories). Live code imports
through them, and the retired tree is compiled into the shipped app. Deleting
this directory on 2026-10-22 with those imports still in place does not produce
a smaller app — it produces a build failure.

Measured Aug 2026 by resolving symlinks to their real paths, deduplicating by
realpath, and taking the transitive import closure at **file** granularity:

| Scope | Retired modules | Retired `.dart` files |
|---|---|---|
| Reachable from live `lib/` code | **295** | 1,781 |
| — of which reachable from `lib/main.dart` (shipped) | 246 | 1,392 |
| Reachable **only** from `test/` | **79** | 335 |
| Reachable from nothing at all | **0** | 169 |
| Total | 373 | 2,285 |

**No retired module is fully dead.** Every one of the 373 has at least one file
reachable from live `lib/` or from a test, so none can be deleted today without
first moving or removing an import. At file granularity there is dead weight —
169 retired files are reachable from nothing — but they are scattered across
modules that are otherwise live.

Counting *direct* imports only gives a misleadingly cheaper picture: 270 modules
are imported directly by live `lib/`, 79 only by tests, and 24 have no direct
importer. All 24 are still pulled in transitively. Eighteen of them
(`*_future` scaffolding, `release_fragility`, `secrets_rotation_gate`,
`single_launch_checklist`, and similar) enter the graph through a single
aggregator, `archive_proof/proof_surface_advice_guard.dart`, which is imported
only by tests. That one file is the cheapest lever in the burn-down.

The work the date commits to:

- **793 live `lib/` files** carry **2,337** `package:archiveme_mobile/features/<retired>`
  import directives that must be removed, re-pointed, or promoted out of
  `retired_sprawl/`.
- **979 `test/` files** import retired modules (1,043 test files import
  `package:archiveme_mobile/features/…` overall).
- 90 modules have exactly one live `lib/` importer and 142 have two or fewer —
  the long tail is cheap; the head is not (`activation` 83 importers, `memory`
  56, `archive_evidence` 43, `pressure_retention` 38, `early_archive` 37).
- Live config files import *through* the retired tree:
  `lib/config/trial_mode.dart`, `lib/config/creator_demo_mode.dart`, and
  `lib/core/config/image_evidence_feature_flags.dart` all import
  `features/recording/recording_dependencies.dart`, a barrel inside
  `retired_sprawl/` that re-exports live `lib/config/` and `lib/core/config/`
  files. That cycle has to be broken before `recording` can go.
- Security-relevant live code lives in the retired tree:
  `features/caregiver/caregiver_feature_flags.dart` backs
  `V1CapabilityRegistry.caregiverMonitoring`, and
  `features/archive_theory/views/theories_screen.dart` is a registered route in
  `lib/router/app_router.dart`. These are not dead scaffolding and cannot be
  deleted with the rest.

Track progress:

```bash
python3 tool/count_retired_feature_imports.py
```

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

## Deletion gate (replace symlinks with outright removal)

Delete `retired_sprawl/` and stop running `restore_lib_features_symlinks.sh` when
**all** of the following are true:

1. **Zero retired imports** — `python3 tool/count_retired_feature_imports.py` exits 0
   (no `package:archiveme_mobile/features/<X>/…` where `<X>` is outside the 14 V1 dirs;
   the script derives that set dynamically, so it already counts `caregiver_grant`).
2. **V1 analyze clean** — `flutter analyze` on the 14 canonical `lib/features/{archive,auth,belief_changes,belief_evidence,capture,caregiver_grant,fact_ledger,insights,onboarding,quick_capture,record,search,settings,sync}` dirs passes CI thresholds without symlink restore.
3. **One stable release** — at least one TestFlight / Play internal track build promoted
   without a P0/P1 regression traced to a retired module (import path or symlink target).
4. **Date ceiling** — **2026-09-30** — if conditions 1–3 are not met by this date,
   schedule a forced import burn-down; do not extend the symlink bridge indefinitely.
   The three weeks between this ceiling and the 2026-10-22 deletion date are reserved
   for conditions 2 and 3 — see [Conflict A](#conflict-a--the-burn-down-ceiling-is-five-weeks-after-the-deletion-date).

Conditions 1–3 are prerequisites for the deletion date, not substitutes for it, and
the deletion date does not waive them. If 2026-10-22 arrives with conditions 1–3
unmet, the correct outcome is an escalated, resourced burn-down — not a deletion
that breaks the build, and not a silent extension.

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
