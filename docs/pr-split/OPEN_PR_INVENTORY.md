# Open Pull Request Inventory — voice-memory

Generated: 2026-08-22. Read-only survey. All figures measured locally against
`origin/*` remote-tracking refs, which were verified byte-identical to `git ls-remote`
output for all 34 refs involved (0 mismatches), so nothing here is truncated by
GitHub's 3000-file API cap.

Method note: unless stated otherwise, a PR's file set is
`git diff --no-renames --name-status $(git merge-base origin/<base> origin/<head>) origin/<head>`.
GitHub's own `changedFiles` uses rename detection; the two agree everywhere except
PR 176 (3422 raw / 1881 rename-detected) and PR 197 (116 raw / 113 rename-detected).

---

## 1. The PR table

32 open PRs, not ~20.

| PR | Head | Base | Stack | Mergeable | CI | Files | +ins | -del |
|----|------|------|-------|-----------|----|-------|------|------|
| 120 | `app-store-screenshot-reviewer-pack` | `main` | solo(120) | CONFLICTING/DIRTY | FAILURE:1 SUCCESS:1 | 4 | 347 | 0 |
| 173 | `cursor/setup-dev-environment-d262` | `cursor/batch9-research-evaluation-598e` | solo(173) | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 1 | 23 | 0 |
| 175 | `archive-me/focused-beta-stabilization` | `main` | B | MERGEABLE/UNSTABLE | FAILURE:5 SKIPPED:2 SUCCESS:3 | 2802 | 294645 | 46 |
| 176 | `split/monorepo-scaffold` | `main` | A | MERGEABLE/UNSTABLE | FAILURE:3 SKIPPED:3 SUCCESS:3 | 3422 | 25175 | 3030 |
| 177 | `split/journal-sqlite-core` | `split/monorepo-scaffold` | A | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 46 | 8142 | 0 |
| 178 | `split/capture-pipeline-sync` | `split/journal-sqlite-core` | A | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 34 | 6010 | 0 |
| 179 | `split/hybrid-search` | `split/journal-sqlite-core` | A | CONFLICTING/DIRTY | FAILURE:1 SUCCESS:1 | 12 | 1129 | 14 |
| 180 | `split/vision-embeddings` | `split/hybrid-search` | A | MERGEABLE/UNSTABLE (first query returned UNKNOWN) | FAILURE:1 SUCCESS:1 | 12 | 931 | 1 |
| 181 | `split/theory-citation-ui` | `split/vision-embeddings` | A | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 28 | 3865 | 0 |
| 182 | `split/transparency-privacy` | `split/theory-citation-ui` | A | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 36 | 4447 | 0 |
| 183 | `split/mesh-mcp-experimental` | `split/monorepo-scaffold` | A | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 25 | 3025 | 0 |
| 184 | `split/capture-flow-ui` | `split/capture-pipeline-sync` | A | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 45 | 6667 | 0 |
| 185 | `split/mobile-project-scaffold` | `archive-me/focused-beta-stabilization` | B | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 118 | 9751 | 4 |
| 186 | `split/retired-sprawl-tracked` | `split/mobile-project-scaffold` | B | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 2287 | 290248 | 0 |
| 187 | `split/analyzer-excludes-symlinks` | `split/retired-sprawl-tracked` | B | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 2 | 537 | 1 |
| 188 | `split/privacy-copy-accuracy` | `archive-me/focused-beta-stabilization` | B | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 22 | 1810 | 38 |
| 189 | `split/llama-cpp-lfs` | `archive-me/focused-beta-stabilization` | B | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 334 | 719949 | 0 |
| 190 | `split/ci-gate-correctness` | `archive-me/focused-beta-stabilization` | B | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 3 | 63 | 42 |
| 191 | `split/evidence-citations` | `archive-me/focused-beta-stabilization` | B | MERGEABLE/UNSTABLE | FAILURE:1 SUCCESS:1 | 20 | 1926 | 102 |
| 192 | `split/main-test-fixture` | `main` | solo(192) | MERGEABLE/UNSTABLE | FAILURE:1 SKIPPED:3 SUCCESS:5 | 2 | 683 | 0 |
| 193 | `split/main-docs-baseline` | `main` | solo(193) | MERGEABLE/UNSTABLE | FAILURE:1 SKIPPED:3 SUCCESS:5 | 2 | 336 | 0 |
| 194 | `split/main-docs-consolidation` | `main` | solo(194) | MERGEABLE/UNSTABLE | FAILURE:1 SKIPPED:3 SUCCESS:5 | 167 | 14571 | 0 |
| 195 | `split/main-security-boundaries` | `main` | C | MERGEABLE/UNSTABLE | FAILURE:2 SKIPPED:3 SUCCESS:4 | 94 | 21517 | 3 |
| 196 | `split/main-lib-landing` | `split/main-security-boundaries` | C | MERGEABLE/CLEAN | SUCCESS:2 | 1517 | 197784 | 1487 |
| 197 | `split/main-gates-budget` | `split/main-lib-landing` | C | MERGEABLE/CLEAN | SUCCESS:2 | 116 | 10876 | 43 |
| 198 | `split/main-gate-cleanup` | `split/main-gates-budget` | C | MERGEABLE/CLEAN | SUCCESS:2 | 26 | 1 | 438 |
| 199 | `split/main-docs-history-removal` | `main` | solo(199) | MERGEABLE/UNSTABLE | FAILURE:1 SKIPPED:3 SUCCESS:5 | 29 | 0 | 6428 |
| 200 | `split/main-research-repoint` | `split/main-lib-landing` | C | MERGEABLE/CLEAN | SUCCESS:2 | 75 | 1332 | 1643 |
| 201 | `split/main-mobile-test-suite` | `split/main-lib-landing` | C | MERGEABLE/CLEAN | SUCCESS:2 | 1154 | 272431 | 0 |
| 202 | `split/main-gitignore-release-logs` | `main` | solo(202) | MERGEABLE/UNSTABLE | FAILURE:1 SKIPPED:3 SUCCESS:5 | 1 | 3 | 0 |
| 203 | `split/main-mobile-scaffold` | `split/main-lib-landing` | C | MERGEABLE/CLEAN | SUCCESS:2 | 117 | 9800 | 0 |
| 204 | `split/main-retire-voicememory-mobile` | `split/main-mobile-scaffold` | C | MERGEABLE/CLEAN | SUCCESS:2 | 7377 | 0 | 2312977 |

`Files` column is the raw (no-rename) count. Draft: only PR 173.

CI reality check: every `CLEAN` PR (196, 197, 198, 200, 201, 203, 204) reports only
2 successful checks, versus 8-10 checks on the PRs that target `main`. Those PRs are
stacked on non-`main` bases, so the full gate suite never runs on them. `CLEAN` here
means 'no merge conflict with its immediate parent branch', not 'validated'.

Failing checks, by check name:

| Check | # PRs | PRs |
|-------|-------|-----|
| Vercel | 19 | 120, 173, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191 |
| flutter-gates | 8 | 175, 176, 192, 193, 194, 195, 199, 202 |
| server-gates | 3 | 175, 176, 195 |
| Backend Typecheck & QA | 1 | 175 |
| Flutter Mobile Build & Test | 1 | 175 |

`Vercel` fails on 19 PRs including trivial one-file ones, so treat it as environmental
rather than as signal about the change.

---

## 2. Stacking graph and merge order

Bases were read from the GitHub API and cross-checked against local refs; none were assumed.

```
main
 |
 +-- 176 split/monorepo-scaffold ...................... STACK A (3422 files)
 |     +-- 177 split/journal-sqlite-core
 |     |     +-- 178 split/capture-pipeline-sync
 |     |     |     +-- 184 split/capture-flow-ui
 |     |     +-- 179 split/hybrid-search           <-- CONFLICTING
 |     |           +-- 180 split/vision-embeddings
 |     |                 +-- 181 split/theory-citation-ui
 |     |                       +-- 182 split/transparency-privacy
 |     +-- 183 split/mesh-mcp-experimental
 |
 +-- 175 archive-me/focused-beta-stabilization ........ STACK B (2802 files)
 |     +-- 185 split/mobile-project-scaffold
 |     |     +-- 186 split/retired-sprawl-tracked
 |     |           +-- 187 split/analyzer-excludes-symlinks
 |     +-- 188 split/privacy-copy-accuracy
 |     +-- 189 split/llama-cpp-lfs
 |     +-- 190 split/ci-gate-correctness
 |     +-- 191 split/evidence-citations
 |
 +-- 195 split/main-security-boundaries ............... STACK C (94 files)
 |     +-- 196 split/main-lib-landing
 |           +-- 197 split/main-gates-budget
 |           |     +-- 198 split/main-gate-cleanup
 |           +-- 200 split/main-research-repoint
 |           +-- 201 split/main-mobile-test-suite
 |           +-- 203 split/main-mobile-scaffold
 |                 +-- 204 split/main-retire-voicememory-mobile
 |
 +-- 120 app-store-screenshot-reviewer-pack  <-- CONFLICTING
 +-- 192 split/main-test-fixture
 +-- 193 split/main-docs-baseline
 +-- 194 split/main-docs-consolidation
 +-- 199 split/main-docs-history-removal
 +-- 202 split/main-gitignore-release-logs

cursor/batch9-research-evaluation-598e   (branch, NOT an open PR)
  +-- 173 cursor/setup-dev-environment-d262   [draft]
```

### PRs whose base is an unmerged PR head (cannot merge until the parent does)

24 of the 32. Explicitly: 177, 178, 179, 180, 181, 182, 183, 184 (stack A);
185, 186, 187, 188, 189, 190, 191 (stack B); 196, 197, 198, 200, 201, 203, 204 (stack C).

Corrections to the stated assumptions:

- The brief says `split/main-*` branches are 'believed to target main'. **Seven of them do not.**
  196, 197, 198, 200, 201, 203 and 204 all carry the `split/main-*` prefix but target other
  `split/main-*` heads. Only 192, 193, 194, 195, 199 and 202 actually target `main`.
- PR 173's base, `cursor/batch9-research-evaluation-598e`, is a branch with **no open PR**.
  It is an orphan stack of one.

### On 'security slice had to precede lib-landing'

Verified and **true**: PR 196 (`split/main-lib-landing`) has base
`split/main-security-boundaries` (PR 195). The intent matches the actual base.
The file dependency is real -- 195 and 196 share 11 files, and all 11 are divergent
(196 modifies files that 195 introduces):
  - `apps/mobile/lib/features/onboarding/remote_processing_consent_copy.dart`
  - `apps/mobile/lib/router/v1_route_inventory.dart`
  - `apps/mobile/lib/router/v1_route_registry.dart`
  - `apps/mobile/lib/screens/export_screen.dart`
  - `apps/mobile/lib/screens/settings_screen.dart`
  - `apps/mobile/lib/security/private_data_service.dart`
  - `apps/mobile/lib/security/release_logger.dart`
  - `apps/mobile/lib/services/app_services.dart`
  - `apps/mobile/lib/services/capture_pipeline_service.dart`
  - `apps/mobile/lib/services/record_pipeline_log.dart`
  - `apps/mobile/lib/startup/archive_me_crash_diagnostics.dart`

### Defensible merge order

The three stacks are not independent (see section 4), so ordering matters between them,
not just within them.

```
 1. 202  .gitignore only, 1 file, zero interaction with anything else
 2. 193  docs/release, 2 files (content already inside 175 identically)
 3. 199  docs/history removal, 29 files, no overlap with any other PR
 4. 192  2 test files (content already inside 175 and 176 identically)
 5. 194  167 docs files (content already inside 175 identically)

 then ONE of the two mobile-landing stacks -- B or C -- not both as-is:

 6. 195 -> 196 -> {197 -> 198, 200, 201, 203 -> 204}     (stack C)
    or
 6. 175 -> {185 -> 186 -> 187, 188, 189, 190, 191}       (stack B)

 7. 176 -> 177 -> {178 -> 184, 179 -> 180 -> 181 -> 182}, 183   (stack A)
    -- must be rebased after whichever of B/C landed; 177/178/183/184 all
       carry divergent versions of files that B and C also carry

 last. 120  needs a manual conflict resolution against main first
 unscheduled. 173  orphan base, cannot merge as-is
```

---

## 3. Per-PR path summary

### PR 120 — Add App Store submission pack
`app-store-screenshot-reviewer-pack` → `main` · stack solo(120) · 4 files

- `apps/voicememory_mobile/APP_STORE_SCREENSHOT_CAPTIONS.md`
- `apps/voicememory_mobile/APP_STORE_SUBMISSION_PACK.md`
- `apps/voicememory_mobile/MANUAL_WALKTHROUGH_CHECKLIST.md`
- `apps/voicememory_mobile/test/app_store_submission_pack_test.dart`

### PR 173 — Set up dev environment + document Cursor Cloud run notes
`cursor/setup-dev-environment-d262` → `cursor/batch9-research-evaluation-598e` · stack solo(173) · 1 files

- `AGENTS.md`

### PR 175 — focused-beta stabilization: consent, storage, logging, and route integrity
`archive-me/focused-beta-stabilization` → `main` · stack B · 2802 files

- `apps/mobile/lib` — 1912
- `apps/web/archived-components` — 422
- `apps/mobile/docs` — 167
- `apps/web/archived-consumer-routes` — 119
- `apps/mobile/tool` — 86
- `apps/mobile/test` — 45
- `apps/web/app` — 16
- `apps/web/components` — 12
- `apps/web/public` — 6
- `docs/release/BASELINE_2026-08-12.md` — 1
- `docs/release/FOCUSED_BETA_DECISIONS.md` — 1
- `docs/privacy/ACTIVE_BETA_DATA_MAP.md` — 1
- …and 14 more prefixes

### PR 176 — Monorepo scaffold: Turbo workspaces, apps/web, apps/api, packages/shared
`split/monorepo-scaffold` → `main` · stack A · 3422 files

- `packages/shared/lib` — 1003
- `apps/web/components` — 432
- `packages/shared/types` — 175
- `apps/web/archived-consumer-routes` — 119
- `apps/api/app` — 48
- `apps/api/src` — 26
- `apps/api/lib` — 20
- `apps/web/app` — 16
- `apps/web/public` — 6
- `lib/live-audio/protocol` — 5
- `lib/live-audio/fixtures` — 5
- `app/api/sync` — 4
- …and 1550 more prefixes

### PR 177 — Mobile journal models and SQLite storage core
`split/journal-sqlite-core` → `split/monorepo-scaffold` · stack A · 46 files

- `apps/mobile/lib` — 35
- `apps/mobile/test` — 9
- `apps/mobile/pubspec.yaml` — 1
- `apps/mobile/pubspec.lock` — 1

### PR 178 — Mobile capture pipeline and sync queue
`split/capture-pipeline-sync` → `split/journal-sqlite-core` · stack A · 34 files

- `apps/mobile/lib` — 20
- `apps/mobile/test` — 14

### PR 179 — Mobile hybrid search and insight engine
`split/hybrid-search` → `split/journal-sqlite-core` · stack A · 12 files

- `apps/mobile/hook/build.dart`
- `apps/mobile/lib/features/insight_engine/hybrid_search_engine.dart`
- `apps/mobile/lib/features/insight_engine/hybrid_search_models.dart`
- `apps/mobile/lib/features/insight_engine/reciprocal_rank_fusion.dart`
- `apps/mobile/lib/src/native/sqlite_vector_extension.dart`
- `apps/mobile/lib/storage/sqlite/memory_transcript_search_repository.dart`
- `apps/mobile/lib/storage/sqlite/migrations/migration_005_hybrid_search.dart`
- `apps/mobile/lib/storage/sqlite/sqlite_migration_runner.dart`
- `apps/mobile/lib/storage/sqlite/sqlite_vector_support.dart`
- `apps/mobile/pubspec.lock`
- `apps/mobile/pubspec.yaml`
- `apps/mobile/test/services/hybrid_search_test.dart`

### PR 180 — Mobile vision embeddings and image attachment search
`split/vision-embeddings` → `split/hybrid-search` · stack A · 12 files

- `apps/mobile/lib/features/vision/image_embedding_inference.dart`
- `apps/mobile/lib/features/vision/image_embedding_service.dart`
- `apps/mobile/lib/features/vision/image_processor.dart`
- `apps/mobile/lib/features/vision/local_visual_projection_inference.dart`
- `apps/mobile/lib/features/vision/offline_image_embedding_guard.dart`
- `apps/mobile/lib/features/vision/onnx_image_embedding_inference.dart`
- `apps/mobile/lib/storage/sqlite/image_attachment_embedding_repository.dart`
- `apps/mobile/lib/storage/sqlite/migrations/migration_006_image_embeddings.dart`
- `apps/mobile/lib/storage/sqlite/sqlite_migration_runner.dart`
- `apps/mobile/test/features/vision/image_embedding_service_test.dart`
- `apps/mobile/test/features/vision/image_processor_test.dart`
- `apps/mobile/test/features/vision/offline_image_embedding_guard_test.dart`

### PR 181 — Mobile archive theory, citations, and x-ray UI
`split/theory-citation-ui` → `split/vision-embeddings` · stack A · 28 files

- `apps/mobile/lib` — 23
- `apps/mobile/test` — 5

### PR 182 — Mobile transparency, privacy, export, and evidence onboarding
`split/transparency-privacy` → `split/theory-citation-ui` · stack A · 36 files

- `apps/mobile/lib` — 28
- `apps/mobile/test` — 8

### PR 183 — Mobile mesh offload and MCP host (experimental)
`split/mesh-mcp-experimental` → `split/monorepo-scaffold` · stack A · 25 files

- `apps/mobile/lib` — 23
- `apps/mobile/test` — 2

### PR 184 — Mobile capture flow UI + pipeline stream consumers
`split/capture-flow-ui` → `split/capture-pipeline-sync` · stack A · 45 files

- `apps/mobile/lib` — 41
- `apps/mobile/test` — 3
- `apps/mobile/pubspec.yaml` — 1

### PR 185 — Track mobile Flutter project scaffolding so mobile CI can run
`split/mobile-project-scaffold` → `archive-me/focused-beta-stabilization` · stack B · 118 files

- `apps/mobile/ios` — 61
- `apps/mobile/android` — 27
- `apps/mobile/integration_test` — 11
- `apps/mobile/linux` — 3
- `apps/mobile/config` — 2
- `apps/mobile/.metadata` — 1
- `packages/archiveme_research/pubspec.yaml` — 1
- `apps/mobile/.gitignore` — 1
- `apps/mobile/openapi` — 1
- `apps/mobile/pubspec.lock` — 1
- `apps/mobile/hook` — 1
- `apps/mobile/pubspec.yaml` — 1
- …and 7 more prefixes

### PR 186 — Track retired_sprawl and restore the stubs 7aaa1262 wrongly deleted
`split/retired-sprawl-tracked` → `split/mobile-project-scaffold` · stack B · 2287 files

- `apps/mobile/retired_sprawl` — 2286
- `apps/mobile/docs` — 1

### PR 187 — Make analyzer excludes actually exclude retired code
`split/analyzer-excludes-symlinks` → `split/retired-sprawl-tracked` · stack B · 2 files

- `apps/mobile/analysis_options.yaml`
- `apps/mobile/tool/restore_lib_features_symlinks.sh`

### PR 188 — Correct privacy copy and make the policy scanner discover its sources
`split/privacy-copy-accuracy` → `archive-me/focused-beta-stabilization` · stack B · 22 files

- `apps/mobile/lib` — 11
- `apps/mobile/test` — 8
- `apps/mobile/tool` — 3

### PR 189 — Vendor llama_cpp_dart via Git LFS
`split/llama-cpp-lfs` → `archive-me/focused-beta-stabilization` · stack B · 334 files

- `packages/llama_cpp_dart/src` — 147
- `packages/llama_cpp_dart/dist` — 83
- `packages/llama_cpp_dart/bin` — 28
- `packages/llama_cpp_dart/lib` — 23
- `packages/llama_cpp_dart/android` — 15
- `packages/llama_cpp_dart/doc` — 9
- `packages/llama_cpp_dart/darwin` — 6
- `packages/llama_cpp_dart/ios` — 5
- `packages/llama_cpp_dart/windows` — 3
- `packages/llama_cpp_dart/linux` — 3
- `packages/llama_cpp_dart/macos` — 2
- `packages/llama_cpp_dart/.gitattributes` — 1
- …and 9 more prefixes

### PR 190 — Stop the self-test gates from passing vacuously
`split/ci-gate-correctness` → `archive-me/focused-beta-stabilization` · stack B · 3 files

- `apps/mobile/tool/gates.yaml`
- `apps/mobile/tool/run_api_dto_self_test.dart`
- `apps/mobile/tool/run_pro_status_self_test.dart`

### PR 191 — Make evidence citations verified and first-class
`split/evidence-citations` → `archive-me/focused-beta-stabilization` · stack B · 20 files

- `apps/mobile/lib` — 18
- `apps/mobile/test` — 2

### PR 192 — Update proof display gate fixture and clean up test suppresses
`split/main-test-fixture` → `main` · stack solo(192) · 2 files

- `apps/mobile/test/first_archive_state_test.dart`
- `apps/mobile/test/proof_admission/proof_display_gate_test.dart`

### PR 193 — Add focused-beta baseline and decision ledger
`split/main-docs-baseline` → `main` · stack solo(193) · 2 files

- `docs/release/BASELINE_2026-08-12.md`
- `docs/release/FOCUSED_BETA_DECISIONS.md`

### PR 194 — Consolidate mobile docs to 15 living files
`split/main-docs-consolidation` → `main` · stack solo(194) · 167 files

- `apps/mobile/docs` — 167

### PR 195 — Mobile security boundaries: consent, encrypted prefs, release logging, route integrity
`split/main-security-boundaries` → `main` · stack C · 94 files

- `apps/mobile/lib` — 45
- `apps/mobile/test` — 43
- `apps/mobile/tool` — 3
- `scripts/validate-privacy-logs.mjs` — 1
- `docs/privacy/LOGGING_POLICY.md` — 1
- `docs/privacy/ACTIVE_BETA_DATA_MAP.md` — 1

### PR 196 — Land mobile lib: V1 feature modules, infrastructure, and UI layer
`split/main-lib-landing` → `split/main-security-boundaries` · stack C · 1517 files

- `apps/mobile/lib` — 1517

### PR 197 — Manifest-driven tool gates and repository budget enforcement
`split/main-gates-budget` → `split/main-lib-landing` · stack C · 116 files

- `apps/mobile/tool` — 112
- `apps/mobile/.gitignore` — 1
- `apps/mobile/.feature_count_budget` — 1
- `.github/workflows/ci.yml` — 1
- `.github/workflows/archiveme-stabilization.yml` — 1

### PR 198 — Drop retired feature gate wrappers and manifest entries
`split/main-gate-cleanup` → `split/main-gates-budget` · stack C · 26 files

- `apps/mobile/tool` — 26

### PR 199 — Remove superseded history documents
`split/main-docs-history-removal` → `main` · stack solo(199) · 29 files

- `docs/history/GPT5_PRO_GATING_AUDIT.md` — 1
- `docs/history/TRAIT_POLLUTION_REMOVAL_PLAN.md` — 1
- `docs/history/EMPTY_STATE_AUDIT.md` — 1
- `docs/history/REBRAND_FIX_REPORT.md` — 1
- `docs/history/TRAIT_POLLUTION_AUDIT.md` — 1
- `docs/history/ARCHIVE_V2_VALIDATION.md` — 1
- `docs/history/REPO_INTEGRITY_AUDIT.md` — 1
- `docs/history/TOPICAL_COUNTER_EVIDENCE_PLAN.md` — 1
- `docs/history/SETTINGS_PRODUCTION_AUDIT.md` — 1
- `docs/history/UNIFIED_THEORY_SELECTION_PLAN.md` — 1
- `docs/history/EMPTY_STATE_FIXES.md` — 1
- `docs/history/ARCHIVE_GROWTH_LOOP_VALIDATION.md` — 1
- …and 17 more prefixes

### PR 200 — Repoint archiveme_research at archiveme_mobile
`split/main-research-repoint` → `split/main-lib-landing` · stack C · 75 files

- `packages/archiveme_research/lib` — 71
- `packages/archiveme_research/pubspec.lock` — 1
- `packages/archiveme_research/pubspec.yaml` — 1
- `packages/archiveme_research/README.md` — 1
- `packages/archiveme_research/.flutter-plugins-dependencies` — 1

### PR 201 — Track the apps/mobile test suite
`split/main-mobile-test-suite` → `split/main-lib-landing` · stack C · 1154 files

- `apps/mobile/test` — 1154

### PR 202 — Ignore release/evidence gate run logs
`split/main-gitignore-release-logs` → `main` · stack solo(202) · 1 files

- `.gitignore`

### PR 203 — Track mobile Flutter project scaffolding
`split/main-mobile-scaffold` → `split/main-lib-landing` · stack C · 117 files

- `apps/mobile/ios` — 61
- `apps/mobile/android` — 27
- `apps/mobile/integration_test` — 11
- `apps/mobile/linux` — 3
- `apps/mobile/config` — 2
- `apps/mobile/.metadata` — 1
- `apps/mobile/.gitignore` — 1
- `apps/mobile/openapi` — 1
- `apps/mobile/pubspec.lock` — 1
- `apps/mobile/hook` — 1
- `apps/mobile/pubspec.yaml` — 1
- `apps/mobile/macos` — 1
- …and 6 more prefixes

### PR 204 — Retire apps/voicememory_mobile
`split/main-retire-voicememory-mobile` → `split/main-mobile-scaffold` · stack C · 7377 files

- `apps/voicememory_mobile/lib` — 2930
- `apps/voicememory_mobile/third_party` — 1563
- `apps/voicememory_mobile/native` — 1440
- `apps/voicememory_mobile/test` — 1019
- `apps/voicememory_mobile/docs` — 157
- `apps/voicememory_mobile/tool` — 108
- `apps/voicememory_mobile/ios` — 56
- `apps/voicememory_mobile/android` — 27
- `apps/voicememory_mobile/macos` — 21
- `apps/voicememory_mobile/windows` — 13
- `apps/voicememory_mobile/linux` — 12
- `apps/voicememory_mobile/integration_test` — 8
- …and 22 more prefixes

---

## 4. Cross-PR overlap  ** the important section **

Across all 32 PRs there are **17577 distinct file paths**.
**2195 paths appear in more than one open PR.**

The critical split is between paths that are byte-identical everywhere they appear
(pure duplication -- git merges these silently and correctly) and paths whose content
differs between PRs (a genuine latent conflict). Blob OIDs and file modes were compared
directly via `git ls-tree`, so this is exact, not inferred.

| Category | Files |
|---|---|
| Appear in >1 open PR | 2195 |
| — content identical in every PR that has them | 1957 |
| — **content divergent between PRs** | **238** |
| —— divergent AND spanning unrelated stacks | **212** |
| —— divergent within one stack (expected parent/child evolution) | 26 |

### 4a. Divergent cross-stack overlap, grouped by PR set

These 212 files are the real problem: two or more PRs in unrelated stacks each carry a
different version of the same path.

| PRs holding divergent copies | Stacks | Files | What it is |
|---|---|---|---|
| 175, 176 | A,B | 110 | `apps/web/archived-consumer-routes/**` — both PRs archive the same Next.js consumer routes, with different content. Also `apps/web/eslint.config.mjs`, `apps/web/tsconfig.json`. |
| 175, 177, 196 | A,B,C | 17 | mobile journal models + SQLite storage core |
| 175, 178, 196 | A,B,C | 13 | capture pipeline + sync queue services |
| 175, 191, 196 | B,C | 8 | belief evidence / insights widgets |
| 175, 195, 196 | B,C | 6 | router registry, security services, startup diagnostics |
| 175, 188, 196 | B,C | 6 | onboarding consent copy, privacy/security settings UI |
| 175, 184, 196 | A,B,C | 6 | core DI providers + live voice screen |
| 177, 201 | A,C | 6 | test files for journal/SQLite |
| 175, 183, 196 | A,B,C | 5 | mesh + MCP services |
| 175, 182, 196 | A,B,C | 4 | onboarding evidence screens, router, export/settings screens |
| 175, 178, 195, 196 | A,B,C | 3 |  |
| 184, 201 | A,C | 3 |  |
| 175, 190, 197 | B,C | 2 |  |
| 175, 182, 195, 196 | A,B,C | 2 |  |
| 175, 197, 198 | B,C | 2 |  |
| 178, 201 | A,C | 2 |  |
| 182, 201 | A,C | 2 |  |
| 120, 204 | C,solo(120) | 1 |  |
| 175, 179, 196 | A,B,C | 1 |  |
| 175, 191, 195 | B,C | 1 |  |
| 175, 186, 194 | B,solo(194) | 1 |  |
| 175, 177, 179, 196 | A,B,C | 1 |  |
| 175, 188, 190, 197, 198 | B,C | 1 |  |
| 175, 188, 195 | B,C | 1 |  |
| 175, 177, 179, 180, 196 | A,B,C | 1 |  |
| 175, 181, 196 | A,B,C | 1 |  |
| 175, 185, 197, 203 | B,C | 1 |  |
| 175, 187, 197 | B,C | 1 |  |
| 177, 179, 184, 185, 203 | A,B,C | 1 |  |
| 177, 179, 185, 203 | A,B,C | 1 |  |
| 179, 201 | A,C | 1 |  |
| 180, 201 | A,C | 1 |  |

### 4b. The single most contended file

`apps/mobile/pubspec.lock` and `apps/mobile/pubspec.yaml` each carry divergent copies in
four or five PRs across all three stacks. `pubspec.lock` is exactly what makes PR 179
conflict today. Any dependency-touching slice of today's work will hit the same file.

### 4c. Full divergent cross-stack file list

- `apps/mobile/.gitignore` — PRs 175, 185, 197, 203 (stacks B,C)
- `apps/mobile/docs/architecture/README.md` — PRs 175, 186, 194 (stacks B,solo(194))
- `apps/mobile/lib/core/constants/database_constants.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/core/di/app_provider_container.dart` — PRs 175, 184, 196 (stacks A,B,C)
- `apps/mobile/lib/core/di/network_providers.dart` — PRs 175, 184, 196 (stacks A,B,C)
- `apps/mobile/lib/core/di/retrofit_providers.dart` — PRs 175, 184, 196 (stacks A,B,C)
- `apps/mobile/lib/core/di/storage_providers.dart` — PRs 175, 184, 196 (stacks A,B,C)
- `apps/mobile/lib/core/di/v1_account_dependencies.dart` — PRs 175, 184, 196 (stacks A,B,C)
- `apps/mobile/lib/features/belief_changes/belief_change_moment_engine.dart` — PRs 175, 191, 196 (stacks B,C)
- `apps/mobile/lib/features/belief_changes/ui/belief_change_pattern_card.dart` — PRs 175, 191, 196 (stacks B,C)
- `apps/mobile/lib/features/belief_evidence/ui/belief_evidence_insight_card.dart` — PRs 175, 191, 196 (stacks B,C)
- `apps/mobile/lib/features/belief_evidence/ui/evidence_trust_copy.dart` — PRs 175, 191, 196 (stacks B,C)
- `apps/mobile/lib/features/belief_evidence/ui/view_source_proof_section.dart` — PRs 175, 191, 196 (stacks B,C)
- `apps/mobile/lib/features/fact_ledger/fact_ledger_citation_service.dart` — PRs 175, 191, 196 (stacks B,C)
- `apps/mobile/lib/features/insights/archive_insights_engine.dart` — PRs 175, 191, 196 (stacks B,C)
- `apps/mobile/lib/features/insights/widgets/xray_panel.dart` — PRs 175, 181, 196 (stacks A,B,C)
- `apps/mobile/lib/features/onboarding/evidence_method_onboarding_copy.dart` — PRs 175, 182, 196 (stacks A,B,C)
- `apps/mobile/lib/features/onboarding/evidence_method_onboarding_screen.dart` — PRs 175, 182, 196 (stacks A,B,C)
- `apps/mobile/lib/features/onboarding/remote_processing_consent_copy.dart` — PRs 175, 195, 196 (stacks B,C)
- `apps/mobile/lib/features/onboarding/ui/onboarding_v1_copy.dart` — PRs 175, 188, 196 (stacks B,C)
- `apps/mobile/lib/features/onboarding/ui/remote_processing_consent_copy.dart` — PRs 175, 188, 196 (stacks B,C)
- `apps/mobile/lib/features/onboarding/ui/remote_processing_consent_step.dart` — PRs 175, 188, 196 (stacks B,C)
- `apps/mobile/lib/models/journal_display_metadata.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/models/journal_display_metadata.freezed.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/models/journal_entry.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/models/journal_proof_data.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/models/journal_proof_data.freezed.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/models/journal_sync_metadata.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/models/journal_sync_metadata.freezed.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/models/journal_sync_push_result.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/router/app_router.dart` — PRs 175, 182, 196 (stacks A,B,C)
- `apps/mobile/lib/router/v1_route_inventory.dart` — PRs 175, 195, 196 (stacks B,C)
- `apps/mobile/lib/router/v1_route_registry.dart` — PRs 175, 195, 196 (stacks B,C)
- `apps/mobile/lib/screens/export_screen.dart` — PRs 175, 182, 195, 196 (stacks A,B,C)
- `apps/mobile/lib/screens/journal_bulk_export_screen.dart` — PRs 175, 182, 196 (stacks A,B,C)
- `apps/mobile/lib/screens/live_voice_session_screen.dart` — PRs 175, 184, 196 (stacks A,B,C)
- `apps/mobile/lib/screens/settings_screen.dart` — PRs 175, 182, 195, 196 (stacks A,B,C)
- `apps/mobile/lib/security/privacy_copy_policy.dart` — PRs 175, 188, 196 (stacks B,C)
- `apps/mobile/lib/security/private_data_service.dart` — PRs 175, 195, 196 (stacks B,C)
- `apps/mobile/lib/security/release_logger.dart` — PRs 175, 195, 196 (stacks B,C)
- `apps/mobile/lib/services/app_services.dart` — PRs 175, 178, 195, 196 (stacks A,B,C)
- `apps/mobile/lib/services/capture_pipeline/capture_pipeline_dependencies.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/capture_pipeline/capture_pipeline_middleware.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/capture_pipeline/capture_proof_analyzer.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/capture_pipeline/capture_voice_persistence.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/capture_pipeline/image_caption_handler.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/capture_pipeline/live_voice_handler.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/capture_pipeline/text_capture_handler.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/capture_pipeline/voice_capture_handler.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/capture_pipeline_service.dart` — PRs 175, 178, 195, 196 (stacks A,B,C)
- `apps/mobile/lib/services/mcp/mcp_consent_store.dart` — PRs 175, 183, 196 (stacks A,B,C)
- `apps/mobile/lib/services/mcp/mcp_host.dart` — PRs 175, 183, 196 (stacks A,B,C)
- `apps/mobile/lib/services/mcp/mcp_permission_gate.dart` — PRs 175, 183, 196 (stacks A,B,C)
- `apps/mobile/lib/services/mesh/mesh_encrypted_transport.dart` — PRs 175, 183, 196 (stacks A,B,C)
- `apps/mobile/lib/services/mesh/mesh_peer_transport.dart` — PRs 175, 183, 196 (stacks A,B,C)
- `apps/mobile/lib/services/record_pipeline_log.dart` — PRs 175, 178, 195, 196 (stacks A,B,C)
- `apps/mobile/lib/services/sync/background_sync_queue_gateway.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/sync/background_sync_queue_worker.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/sync/deferred_proof_admission_reconciler.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/sync/journal_save_sync_enqueue_interceptor.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/services/sync/sync_pipeline_log.dart` — PRs 175, 178, 196 (stacks A,B,C)
- `apps/mobile/lib/startup/archive_me_crash_diagnostics.dart` — PRs 175, 195, 196 (stacks B,C)
- `apps/mobile/lib/storage/drift/journal_database.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/drift/sqflite_executor.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/drift/tables/journal_entries.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/sqlite/app_sqlite_database.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/sqlite/journal_sqlite_log.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/sqlite/journal_sqlite_repository.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/sqlite/memory_transcript_search_repository.dart` — PRs 175, 179, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/sqlite/pro_status_sqlite_repository.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/sqlite/sqlite_migration.dart` — PRs 175, 177, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/sqlite/sqlite_migration_runner.dart` — PRs 175, 177, 179, 180, 196 (stacks A,B,C)
- `apps/mobile/lib/storage/sqlite/sqlite_vector_support.dart` — PRs 175, 177, 179, 196 (stacks A,B,C)
- `apps/mobile/lib/ui/screens/settings/privacy_security_screen.dart` — PRs 175, 188, 196 (stacks B,C)
- `apps/mobile/lib/widgets/archive/archive_insight_card.dart` — PRs 175, 191, 196 (stacks B,C)
- `apps/mobile/lib/widgets/settings/privacy_security_trust_section.dart` — PRs 175, 188, 196 (stacks B,C)
- `apps/mobile/pubspec.lock` — PRs 177, 179, 185, 203 (stacks A,B,C)
- `apps/mobile/pubspec.yaml` — PRs 177, 179, 184, 185, 203 (stacks A,B,C)
- `apps/mobile/test/capture_flow/capture_flow_dependency_test.dart` — PRs 184, 201 (stacks A,C)
- `apps/mobile/test/capture_flow/capture_flow_production_path.dart` — PRs 184, 201 (stacks A,C)
- `apps/mobile/test/capture_flow/capture_flow_state_machine_test.dart` — PRs 184, 201 (stacks A,C)
- `apps/mobile/test/capture_pipeline/capture_pipeline_background_processing_test.dart` — PRs 178, 201 (stacks A,C)
- `apps/mobile/test/capture_pipeline/capture_pipeline_test_support.dart` — PRs 178, 201 (stacks A,C)
- `apps/mobile/test/features/export/journal_bulk_export_test.dart` — PRs 182, 201 (stacks A,C)
- `apps/mobile/test/features/onboarding/evidence_method_onboarding_test.dart` — PRs 182, 201 (stacks A,C)
- `apps/mobile/test/features/vision/image_embedding_service_test.dart` — PRs 180, 201 (stacks A,C)
- `apps/mobile/test/journal_entry_test.dart` — PRs 177, 201 (stacks A,C)
- `apps/mobile/test/remote_processing_consent_copy_test.dart` — PRs 175, 188, 195 (stacks B,C)
- `apps/mobile/test/services/hybrid_search_test.dart` — PRs 179, 201 (stacks A,C)
- `apps/mobile/test/storage/sqlite/fact_ledger_migration_test.dart` — PRs 177, 201 (stacks A,C)
- `apps/mobile/test/storage/sqlite/journal_sqlite_repository_test.dart` — PRs 177, 201 (stacks A,C)
- `apps/mobile/test/storage/sqlite/pro_status_migration_test.dart` — PRs 177, 201 (stacks A,C)
- `apps/mobile/test/storage/sqlite/pro_status_sqlite_repository_test.dart` — PRs 177, 201 (stacks A,C)
- `apps/mobile/test/storage/sqlite/user_relationships_migration_test.dart` — PRs 177, 201 (stacks A,C)
- `apps/mobile/test/support/release_suite_static_state_reset.dart` — PRs 175, 191, 195 (stacks B,C)
- `apps/mobile/tool/archive/validate_core.sh` — PRs 175, 197, 198 (stacks B,C)
- `apps/mobile/tool/gates.yaml` — PRs 175, 188, 190, 197, 198 (stacks B,C)
- `apps/mobile/tool/restore_lib_features_symlinks.sh` — PRs 175, 187, 197 (stacks B,C)
- `apps/mobile/tool/run_api_dto_self_test.dart` — PRs 175, 190, 197 (stacks B,C)
- `apps/mobile/tool/run_gate.py` — PRs 175, 197, 198 (stacks B,C)
- `apps/mobile/tool/run_pro_status_self_test.dart` — PRs 175, 190, 197 (stacks B,C)
- `apps/voicememory_mobile/APP_STORE_SUBMISSION_PACK.md` — PRs 120, 204 (stacks C,solo(120))
- `apps/web/archived-consumer-routes/_archived/account/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/archive-belief/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/archive-detail/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/archive/ArchivePageClient.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/archive/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/blind-spots/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/bookmarks/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/creator-kit/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/creator-preview/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/debug/callbacks/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/debug/changes/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/debug/patterns/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/debug/retention/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/discover/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/entry/[id]/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/export/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/export/print/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/feelings-timeline/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/insights/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/intentions/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/invite/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/journal/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/memory/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/monthly/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/open-loops/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/pilot/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/pricing/PricingPageClient.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/pricing/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/record/layout.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/record/loading.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/record/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/reminders/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/roundups/[period]/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/roundups/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/search/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/seasons/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/settings/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/territories/[slug]/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/territories/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/theories/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/threads/[slug]/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/threads/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/timeline/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/updates/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/_archived/weekly/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/demo/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/activation/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/apple-store-readiness/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/archive-attachment/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/archive-belief/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/archive-divergence/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/archive-individuality/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/archive-moat/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/archive-reputation/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/archive-simplicity/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/archive-voice/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/auth-value-validation/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/behavior-truth/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/blind-spot-discovery/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/blind-spot-performance/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/callback-learning/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/conversion/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/distribution/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/durability-review/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/emotional-integrity/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/entitlements/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/first-magic-moment/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/first-week-retention/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/founder-review/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/founder-test/FounderTestShell.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/google-play-readiness/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/launch/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/layout.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/mobile-archive-review/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/mobile-parity/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/mobile-push-readiness/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/mobile-readiness/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/mobile-web-parity/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/north-star/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/onboarding-clarity/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/open-loop-activation/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/open-loop-performance/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/open-loops-readout/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/organic-referral/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/paywall-attribution/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/performance-health/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/product-simplification/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/push-verification/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/recurrence-density/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/reflection-friction/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/restore-verification/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/resurfacing-confidence/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/resurfacing-timing/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/resurfacing-variety/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/retention-core/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/retention-discovery/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/return-trigger-attribution/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/return/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/revenuecat-verification/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/sacredness-review/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/silence-intelligence/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/store-readiness/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/theory-curiosity/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/theory-discovery/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/transcript-cleanup/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/internal/vulnerability-timing/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/archived-consumer-routes/launch/page.tsx` — PRs 175, 176 (stacks A,B)
- `apps/web/eslint.config.mjs` — PRs 175, 176 (stacks A,B)
- `apps/web/tsconfig.json` — PRs 175, 176 (stacks A,B)

### 4d. Whole-PR containment (duplication, not conflict)

| Contained PR | Container PR | Files | Blobs |
|---|---|---|---|
| 196 (`split/main-lib-landing`) | 175 (`archive-me/focused-beta-stabilization`) | 1517 | all identical |
| 194 (`split/main-docs-consolidation`) | 175 | 167 | all identical |
| 203 (`split/main-mobile-scaffold`) | 185 (`split/mobile-project-scaffold`) | 117 | all identical |
| 193 (`split/main-docs-baseline`) | 175 | 2 | all identical |
| 192 (`split/main-test-fixture`) | 175, and separately 176 | 2 | all identical |

---

## 5. Conflicted PRs

Two PRs report a conflict. Probed with the non-writing form of `git merge-tree`.

**PR 120** (`app-store-screenshot-reviewer-pack` → `main`) — conflicts with `main`.
One file, `apps/mobile`-unrelated:

- `apps/voicememory_mobile/APP_STORE_SUBMISSION_PACK.md` — 'added in both'. `main` gained
  its own copy of this file after PR 120 branched off (merge-base `0598ad67`), so the two
  independent additions collide. One real conflict hunk.

Note PR 120 adds four files under `apps/voicememory_mobile/`, the very tree PR 204 deletes
in full. Even after resolving the conflict, 120 and 204 semantically annihilate each other.

**PR 179** (`split/hybrid-search` → `split/journal-sqlite-core`) — conflicts with its own
parent branch, which has advanced (merge-base `cbada974`, parent tip now `d5223b85`).
Conflicting files:

- `apps/mobile/pubspec.lock` — changed in both, real conflict markers
- `apps/mobile/pubspec.yaml` — changed in both, real conflict markers

Both are dependency manifests; PR 178 landed dependency changes on the shared parent while
179 changed the same lines. Everything else in 179 applies cleanly.

PR 180 briefly reported `UNKNOWN`/`UNKNOWN` (GitHub had not finished computing it); on
re-query it settled to `MERGEABLE`.

---

## 6. Empty and superseded PRs

No PR is empty — every one has at least one file of diff against its own base.

Superseded / duplicated (reported only; nothing closed):

- **PR 203 is a duplicate of PR 185.** 117 of 185's 118 files, byte-identical. The only
  file 185 has that 203 lacks is `packages/archiveme_research/pubspec.yaml`. Same titles
  too ('Track mobile Flutter project scaffolding'). They sit in different stacks (B and C),
  so both would apply, and the second to land would be a no-op or a conflict.
- **PR 196's entire content is already inside PR 175**, 1517 files byte-identical.
  Whichever lands second contributes nothing new.
- **PR 194's entire content is already inside PR 175**, 167 files byte-identical.
- **PR 193 and PR 192** are likewise wholly contained in 175 (and 192 also in 176).
- **PR 120 is functionally superseded by PR 204**, which deletes the whole
  `apps/voicememory_mobile/` tree that 120 adds documents to.

These are not bugs in the PRs; they are the signature of the same working tree having been
sliced twice, once as stack B and once as stack C.

---

## 7. Contested paths vs open PRs

Today's stated work areas, mapped to the open PRs that already touch them.
Counts are files within that prefix.

| Path | Open PRs already touching it |
|---|---|
| `features/auth` | #175(5), #195(1), #196(4) |
| `retired_sprawl/auth (symlink target)` | — none — |
| `features/caregiver` | — none — |
| `retired_sprawl/caregiver (symlink target)` | #186(12) |
| `features/privacy` | #182(1) |
| `retired_sprawl/privacy (symlink target)` | #186(5) |
| `features/trust` | #195(1) |
| `retired_sprawl/trust (symlink target)` | #186(12) |
| `features/belief_evidence` | #175(5), #191(13), #196(5) |
| `retired_sprawl/belief_evidence (symlink target)` | — none — |
| `features/onboarding` | #175(36), #182(2), #188(4), #195(1), #196(36) |
| `retired_sprawl/onboarding (symlink target)` | #186(30) |
| `features/settings` | #175(3), #188(4), #196(3) |
| `retired_sprawl/settings (symlink target)` | — none — |
| `features/voice_capture` | #195(4) |
| `retired_sprawl/voice_capture (symlink target)` | #186(28) |
| `lib/security` | #175(38), #188(1), #195(8), #196(32) |
| `lib/models` | #175(20), #177(10), #196(20) |
| `lib/storage` | #175(83), #177(18), #179(4), #180(3), #195(4), #196(79) |
| `lib/screens` | #175(36), #182(5), #184(2), #195(2), #196(36) |
| `lib/ui` | #175(6), #188(1), #196(6) |
| `lib/services` | #175(99), #178(19), #183(23), #195(3), #196(99) |
| `test` | #175(45), #176(2), #177(9), #178(14), #179(1), #180(3), #181(5), #182(8), #183(2), #184(3), #188(8), #191(2), #192(2), #195(43), #201(1154) |
| `tool` | #175(86), #187(1), #188(3), #190(3), #195(3), #197(112), #198(26) |
| `ios/Runner` | #185(37), #203(37) |
| `api coach/consent` | #176(2) |
| `shared/caregiver` | #176(1) |
| `shared/coach` | #176(1) |
| `shared/consent` | — none — |
| `shared/server` | #176(63) |
| `analysis_options.yaml` | #187(1) |

### The symlink trap in this table

Four of today's stated work directories are **not directories**. In the current index and
working tree, `apps/mobile/lib/features/{caregiver,privacy,trust,voice_capture}` are
symlinks (mode `120000`) pointing at `../../retired_sprawl/lib_features/<name>`.

Edits made 'in' those paths today physically landed under `apps/mobile/retired_sprawl/`:

| Directory | Recently-modified files under retired_sprawl |
|---|---|
| `caregiver` | 12 of 12 |
| `privacy` | 5 of 5 |
| `trust` | 2 of 12 |
| `voice_capture` | 18 of 32 |

`apps/mobile/retired_sprawl/` is exactly the tree **PR 186** adds (2286 files). So today's
caregiver/privacy/trust/voice_capture work is not new-file work in `lib/features/` at all —
it is a modification of PR 186's file set, and will conflict with it directly.

By contrast `auth`, `belief_evidence`, `onboarding` and `settings` are genuine directories
with regular files, so work there behaves normally.

---

## 8. Symlink integrity

Confirmed: **373 symlinks** under `apps/mobile/lib/features/` in the index, mode `120000`,
409 in the repository overall. Verified across every PR head.

**No open PR flattens a symlink into a regular file or directory.** A mode-flip scan across
all 32 PR diffs (comparing source mode to destination mode on every changed path) found
**zero** flips. On that specific question the answer is clean.

Two corrections to the premise, though:

1. **PRs 186 and 187 do not create the symlinks — PR 175 does.** 175's diff introduces all
   373. 186's diff contains 2286 files under `apps/mobile/retired_sprawl/` plus one
   unrelated doc edit, and touches no symlink. 187 is two files
   (`apps/mobile/analysis_options.yaml`, `apps/mobile/tool/restore_lib_features_symlinks.sh`).

2. **All 373 symlinks are dangling in PR 175's own tree.** Their targets under
   `apps/mobile/retired_sprawl/lib_features/` are not tracked at 175, nor at 185. They
   resolve only once PR 186 lands: 373/373 dangling at 175, 0/373 dangling at 186.
   Merging 175 to `main` without 186 puts 373 broken symlinks on `main`.

### The real corruption risk (not the one asked about)

Stack B represents `apps/mobile/lib/features/<name>` as a **symlink to a directory**.
Stacks A and C represent **regular files inside** several of those same directories.
Git cannot hold both: a path is either a symlink or a tree. These 10 directories collide.

The "from" column names the PR whose diff *introduces* the file. Because stack C is stacked,
every descendant of 195 (196, 197, 198, 200, 201, 203, 204) carries these files in its tree
too, and likewise every descendant of 177 in stack A.

| Directory (symlink in 175/185/186/187) | Regular files inside it, from | Count |
|---|---|---|
| `activation` | #195 | 1 |
| `archive_search` | #177 | 1 |
| `billing` | #195 | 1 |
| `journal` | #177 | 1 |
| `memory` | #177 | 1 |
| `pattern_naming` | #195 | 1 |
| `proof_admission` | #195 | 3 |
| `recording` | #195 | 1 |
| `trust` | #195 | 1 |
| `voice_capture` | #195 | 4 |

The 15 colliding files:

- `apps/mobile/lib/features/activation/archive_insight_feedback.dart` — from #195
- `apps/mobile/lib/features/archive_search/archive_entry_search_engine.dart` — from #177
- `apps/mobile/lib/features/billing/application/billing_notifier.dart` — from #195
- `apps/mobile/lib/features/journal/presentation/models/journal_display_presentation.dart` — from #177
- `apps/mobile/lib/features/memory/memory_surfacing_mode.dart` — from #177
- `apps/mobile/lib/features/pattern_naming/pattern_name_store.dart` — from #195
- `apps/mobile/lib/features/proof_admission/remote_processing_consent_store.dart` — from #195
- `apps/mobile/lib/features/proof_admission/remote_processing_data_flow.dart` — from #195
- `apps/mobile/lib/features/proof_admission/remote_processing_purpose.dart` — from #195
- `apps/mobile/lib/features/recording/recording_state_controller.dart` — from #195
- `apps/mobile/lib/features/trust/privacy_screen_copy.dart` — from #195
- `apps/mobile/lib/features/voice_capture/analysis/analysis_log.dart` — from #195
- `apps/mobile/lib/features/voice_capture/audio/audio_diag_log.dart` — from #195
- `apps/mobile/lib/features/voice_capture/transcription/provisional_transcript_reconciler.dart` — from #195
- `apps/mobile/lib/features/voice_capture/transcription/transcription_log.dart` — from #195

Note `voice_capture` and `trust` appear in this list **and** in today's work areas.

---

## 9. PR 204 — the deletion count, measured

Measured three ways. Rename detection is the whole story.

| Method | Files | Insertions | Deletions |
|---|---|---|---|
| vs its own base `split/main-mobile-scaffold` (merge-base `2f2ddb59`), `--no-renames` | **7377** | 0 | **2,312,977** |
| same, rename detection on (`-M`) | 7377 | 0 | 2,312,977 |
| same, `-M -l0 --find-copies-harder` | 7377 | — | — |
| vs `main` (whole stack collapsed), `--no-renames` | 9094 | — | — |
| vs `main`, rename detection on (`-M`) | 8125 | — | — |

**Conclusion.** Against its own base the answer is unambiguous and rename-detection-proof:
**7,377 files, all deletions, 2,312,977 lines removed, 100% under `apps/voicememory_mobile/`**
(zero paths outside that prefix). Rename detection changes nothing there, because the diff
contains no additions for git to pair deletions against.

The earlier 6,230 / 5,515 figures came from measuring against `main` instead of against the
PR's own base. Over that range git sees `apps/voicememory_mobile/X` deleted and
`apps/mobile/X` added and pairs them: 9094 raw entries collapse to 8125, i.e. **969 renames**
detected. Git also emits `warning: exhaustive rename detection was skipped due to too many
files` there, so that number is itself unstable and depends on `diff.renameLimit`. Any
figure produced that way should be discarded.

So: the '7,377 deletions' claim is right about the count but it is 7,377 **files**, not lines.

---

## 10. Riskiest thing about the current PR set

**The same body of mobile work has been sliced twice, into two stacks that are both open,
and they disagree about whether `apps/mobile/lib/features/` contains code or symlinks.**

Stack B (175 + 185/186/187/188/189/190/191) and stack C (195 + 196/197/198/200/201/203/204)
are alternative packagings of one working tree. The evidence:

- PR 196's 1517 files are byte-identical inside PR 175.
- PR 203's 117 files are byte-identical inside PR 185.
- PR 194's 167 files are byte-identical inside PR 175.

Landing both is not additive; it is landing the same change twice by two different routes.
And the two routes are not merely redundant, they are **structurally incompatible**: stack B
puts a symlink at `apps/mobile/lib/features/voice_capture`, stack C puts
`apps/mobile/lib/features/voice_capture/analysis/analysis_log.dart` inside it. Whichever
lands second will either conflict at the tree level or silently replace the other's
representation — and if it is the symlink that loses, 28 files of real code under
`retired_sprawl/lib_features/voice_capture` quietly stop being reachable at the path the
app imports.

This is worse than an ordinary conflict because git will not always flag it. A symlink
replaced by a directory is a legal change; nothing warns you that it was unintended.

Ranked below that:

2. **24 of 32 PRs cannot merge until a parent does**, and the stack C members that look
   healthiest (`CLEAN`, all checks green) are the ones running the *fewest* checks, because
   their base is not `main`. Their green is not evidence.
3. **`apps/mobile/pubspec.lock` / `pubspec.yaml` are divergent across four to five PRs in all
   three stacks.** This is already the live cause of PR 179's conflict and will recur.
4. **PR 175 alone would put 373 dangling symlinks on `main`** if merged ahead of PR 186,
   which is two levels below it in the same stack.
5. **PR 189 vendors 719,949 added lines via Git LFS** across 334 files. Nothing overlaps it,
   but it is unreviewable in practice and irreversible in repo-size terms.

---

## 11. Things in the brief that turned out to be wrong

| Claim | Finding |
|---|---|
| 'Roughly 20 open PRs' | **32** open PRs. |
| '`split/main-*` ones are believed to target `main`' | Only 6 of 13 do (192, 193, 194, 195, 199, 202). 196, 197, 198, 200, 201, 203, 204 target other `split/main-*` heads. |
| 'one PR retires `apps/voicememory_mobile` with about 7,377 deletions' | 7,377 is the **file** count, not the line count. Lines deleted: 2,312,977. |
| 'earlier counts 6,230 and 5,515' | Both are artifacts of diffing against `main` with rename detection across the monorepo migration (969 renames detected, and git warns detection was truncated). Against the PR's own base the count is 7,377 by every method. |
| 'a security slice had to precede a lib-landing slice' | **Correct.** 196's base really is 195, and the 11 files they share are all divergent. |
| 'two PRs concern retired_sprawl and symlink restoration' | 186 and 187 are those PRs, but **neither touches the symlinks**. PR 175 creates all 373. 186 supplies their targets; 187 adds `analysis_options.yaml` and edits the restore script. |
| '373 symlinks ... confirm these PRs preserve them' | Confirmed preserved — zero mode flips in any of the 32 PRs. But the meaningful risk is elsewhere: 11 of those symlinked directories are shadowed by regular files in stacks A and C. |
| 'a PR is reported at over 2,000 files' | Two are: 175 (2802) and 186 (2287). 176 is 3422 raw / 1881 rename-detected. |

---

## 12. Confidence and gaps

High confidence (measured directly from git objects, exact):
PR count, bases, file sets, file counts, blob-level overlap classification, symlink modes
and counts, PR 204's deletion figures, containment relationships.

Medium confidence:
the *semantic* labels in the overlap grouping table (section 4a) — the file counts and PR
sets are exact, the 'what it is' column is my reading of the paths.

Lower confidence / not established:

- Why `Vercel` fails on 19 PRs. I did not open the check logs.
- Whether the 26 same-stack divergent files are intentional evolution or accidental
  reversion. I classified them as expected without reading the diffs.
- For PR 179 I confirmed real conflict markers in `pubspec.lock` and `pubspec.yaml`;
  I did not attempt a resolution.
- Today's uncommitted work is deliberately out of scope, except where I needed the current
  index to answer the symlink question.

---

## 13. Read-only attestation

No git write command was run. No `gh` mutating command was run. No file in the repository
was created, modified or deleted.

Commands used against the repo, all read-only:
`git rev-parse`, `git remote -v`, `git branch --list`, `git for-each-ref`, `git ls-remote`,
`git merge-base`, `git diff` (`--name-status`, `--numstat`, `--raw`), `git ls-tree`,
`git ls-files`, `git cat-file -p`, `git status --porcelain`, `git merge-tree` (the
three-argument non-writing form, which produces output only and creates no objects or refs),
plus `find`/`readlink` for worktree inspection.

`gh` usage: `gh pr list --json ...` and `gh pr view --json ...` only.

No `git fetch` was performed either — local remote-tracking refs were verified current
against `git ls-remote` rather than updated.

All intermediate artifacts were written to `/tmp`:
`/tmp/prs.json`, `/tmp/pr_oids.json`, `/tmp/pr_checks.json`, `/tmp/pr_counts.json`,
`/tmp/pr_filesets.json`, `/tmp/pr_pairs.json`, `/tmp/pr_pair_detail.json`,
`/tmp/overlap.json`, `/tmp/contested.json`, `/tmp/symlink_collisions.json`,
`/tmp/prfiles/<pr>.norename.tsv` and `/tmp/prfiles/<pr>.rename.tsv`.
