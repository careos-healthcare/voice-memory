# PR Partition Plan — voice-memory

Read-only analysis. 2026-08-22. All 32 open PRs accounted for.

**Reference point.** "Stack B" below means the projected result of landing PR 175 →
185 → 186 → 187 → {188, 189, 190, 191}. Two concrete objects are used:

- `B-tip` = `origin/split/analyzer-excludes-symlinks` (PR 187's tree). This already
  contains 175 + 185 + 186 + 187 in one commit, so it is a real, inspectable tree.
- `B-final` = `B-tip` overlaid with the post-states of PRs 188, 189, 190, 191
  (which branch off 175, not off 187). 15,187 paths.

**Method.** Per-PR file sets are
`git diff --no-renames --raw --abbrev=40 -z $(git merge-base origin/<base> origin/<head>) origin/<head>`,
compared against `git ls-tree -r --full-tree` of the stack-B refs. Comparison is on
`(mode, blob OID)` — exact, not heuristic. Conflict probing used the three-argument
non-writing `git merge-tree <merge-base> <stack-B-tip> <PR-head>`, which simulates
applying the PR's delta onto stack B.

> **Method warning that matters.** `git diff --raw` abbreviates blob OIDs by default.
> An earlier pass of this analysis silently produced garbage because 7-character OIDs
> were compared against 40-character `ls-tree` OIDs and nothing ever matched.
> `--abbrev=40` is mandatory. Any prior analysis that used `--raw` without it should
> be re-checked.

**Working tree is moving.** Eleven agents are writing here. `git status --porcelain -uall`
returned 15,044 entries at the start of this analysis and 15,050 at the end, ~40 minutes
apart. HEAD stayed at `cc346da9` (= PR 175's tip) throughout. Every statement below about
*committed* refs is stable; every statement about the working tree is a snapshot and is
labelled as such.

**Refs verified current.** All 34 branches involved were compared to `git ls-remote origin`:
0 mismatches, and every PR's `headRefOid` equals the remote ref. No fetch was performed.

---

## 1. The three-bucket partition

### Bucket 1 — provably duplicative, safe to close

Six PRs. For each, the claim being asserted is the strong one: **no file in this PR is
absent from stack B, and no file differs in content from what stack B already carries.**

| PR | Files | Evidence |
|----|-------|----------|
| 192 | 2 | Both blobs identical to PR 175's tree **and** to PR 176's tree. `merge-tree` onto B-tip: **0 bytes of output**. |
| 193 | 2 | Both blobs identical to PR 175's tree. `merge-tree` onto B-tip: **0 bytes**. |
| 194 | 167 | 167/167 blobs identical to PR 175's tree. 166 also identical at B-final. |
| 196 | 1517 | 1517/1517 blobs identical to PR 175's tree **and** to B-tip. `merge-tree` onto B-tip: **0 bytes**. |
| 198 | 26 | 23 deletions target paths that exist in no stack-B ref and in no `main` tree; 3 remaining files match B-tip. `merge-tree` onto B-tip: **0 bytes**. |
| 203 | 117 | 117/117 blobs identical to PR 185's diff post-states. `merge-tree` onto B-tip: **0 bytes**. |

`merge-tree` returning zero bytes is the strongest available statement: git's own
three-way merge machinery finds *nothing to do* when the PR's delta is applied to stack B.

**Two of the six need their caveat stated, not buried.**

- **PR 194.** All 167 blobs are byte-identical to PR 175's tree. But PR 186 later modifies
  one of them, `apps/mobile/docs/architecture/README.md`. So against B-*final* the count
  is 166 identical + 1 where stack B carries a *later revision of the same file* whose
  earlier revision is exactly 194's blob (supplied by 175). `merge-tree` reports one
  add/add conflict on that path purely because it has no shared history to reason from.
  Nothing is lost by closing 194. This is also an internal contradiction in
  `OPEN_PR_INVENTORY.md`, which claimed 194 is "167 files, all identical" in §4d while
  listing that exact file as divergent across 175/186/194 in §4c.

- **PR 196.** All 1517 blobs are byte-identical to 175 and to B-tip. Against B-final, 14
  files have later revisions because PRs 188 (6 files) and 191 (8 files) modify them on
  top of 175. Since 196's blobs equal the merge-base content in those 14 cases, 196
  contributes no change to them and there is **no revert risk** if it landed after
  188/191. It is a strict no-op relative to stack B.

**PR 198 has an ordering dependency.** Its 23 deletions are meaningful only in stack C,
where PR 197 creates those files two commits earlier. 198 must be closed together with
or after 197 is resolved; on its own, against stack B, it does nothing.

### Bucket 2 — unique, must be preserved

| PR | Files | What is unique | Conflicts onto stack B |
|----|-------|----------------|------------------------|
| **201** | 1154 | **1149 of 1154 blobs exist nowhere in stack B**, at any path. This is the `apps/mobile/test/` suite. Stack B's 175 carries only 45 test files. | **0** (`merge-tree`: no conflicts) |
| **204** | 7377 | Deletes all of `apps/voicememory_mobile/`. Stack B carries all 7377 of those files (`main`: 7377, B-tip: 7377 — exact match). | **0** |
| **199** | 29 | Deletes 29 of the 60 `docs/history/*.md` files. All 29 verified present in B-tip. | **0** |
| **202** | 1 | Appends 3 lines (`/release/evidence/`) to root `.gitignore`. Stack B's `.gitignore` is byte-identical to `main`'s, so this is genuinely new. | **0** |
| **200** | 75 | Repoints `packages/archiveme_research` at `archiveme_mobile`: 73 files differ from stack B's copies (import rewrites, plus `ask_archive_screen.dart` at −388 lines), 1 new file. | **0** |
| **120** | 4 | 3 files absent from stack B entirely. | 1 add/add on `APP_STORE_SUBMISSION_PACK.md` (also conflicts with `main`) |
| **173** | 1 | `AGENTS.md` edit. Base branch `cursor/batch9-research-evaluation-598e` has no open PR. | not applicable — orphan base |
| 176–184 (stack A) | 3422 + 263 | Genuinely different work: `packages/shared` (1003 files), `apps/api`, `apps/web` monorepo scaffold, mesh/MCP, vision embeddings. 1706 of 176's paths are absent from stack B. | heavy: 176 → 110 add/add, 177 → 21 add/add & 129 hunks, 183 → 5 add/add |

**Disclosures against the strict bucket definition.** PR 200 has exactly 1 of 75 files
(`packages/archiveme_research/pubspec.yaml`) byte-identical to stack B's copy (from PR 185),
and PR 120 has 1 of 4 in add/add conflict. Both are placed in bucket 2 rather than 3
because they need no split — closing either would destroy 74 and 3 files respectively,
and the overlap is a single file that merges trivially.

**PR 201 is the single most important finding in this document.** It is a stack-C PR
based on `split/main-lib-landing`, so a wholesale "close stack C" would take it out, and
the prior inventory never flagged it as carrying unique content. 1,149 test files exist in
no stack-B PR. They are not moved copies of `apps/voicememory_mobile/test/` either: at the
corresponding relative path there, 946 are divergent and 203 are absent, with only 5
byte-identical.

### Bucket 3 — mixed, dangerous

**PR 195** (94 files) — `split/main-security-boundaries`, base `main`.

| Group | Count | Paths / disposition |
|---|---|---|
| Byte-identical to stack B | 66 | `lib/security/*`, `lib/storage/*`, `test/*`, `docs/privacy/*`, `scripts/validate-privacy-logs.mjs` — nothing to preserve |
| Identical to a stack-B variant | 2 | `test/support/release_suite_static_state_reset.dart` (= B before 191), `test/remote_processing_consent_copy_test.dart` (= B before 188) — stack B is ahead |
| **Divergent, direction unclear** | **11** | `lib/features/onboarding/remote_processing_consent_copy.dart`, `lib/router/v1_route_inventory.dart`, `lib/router/v1_route_registry.dart`, `lib/screens/export_screen.dart`, `lib/screens/settings_screen.dart`, `lib/security/private_data_service.dart`, `lib/security/release_logger.dart`, `lib/services/app_services.dart`, `lib/services/capture_pipeline_service.dart`, `lib/services/record_pipeline_log.dart`, `lib/startup/archive_me_crash_diagnostics.dart` |
| "New" but actually present in stack B behind a symlink | 12 | see below |
| "New" but present in stack B at a different path | 2 | `tool/validate_mobile_privacy_logs.dart`, `tool/validate_production_route_links.dart` — byte-identical to stack B's `tool/archive/` copies |
| Genuinely new content | 1 | `tool/validate_v1_production_graph.sh` — differs from stack B's `tool/archive/` copy by 3 deleted lines |

The 12 "new" files land under `apps/mobile/lib/features/{activation,billing,pattern_naming,
proof_admission,recording,trust,voice_capture}`, all of which are **symlinks** in stack B.
Resolving each through its symlink to `apps/mobile/retired_sprawl/lib_features/`:

- **8 are byte-identical** to stack B's copy: `activation/archive_insight_feedback.dart`,
  `billing/application/billing_notifier.dart`, `pattern_naming/pattern_name_store.dart`,
  `proof_admission/remote_processing_data_flow.dart`,
  `proof_admission/remote_processing_purpose.dart`,
  `voice_capture/analysis/analysis_log.dart`,
  `voice_capture/transcription/provisional_transcript_reconciler.dart`,
  `voice_capture/transcription/transcription_log.dart`.
- **4 differ, and in all four cases 195's version is strictly thinner**:
  `proof_admission/remote_processing_consent_store.dart` (−10 lines),
  `recording/recording_state_controller.dart` (−5),
  `trust/privacy_screen_copy.dart` (+5/−13),
  `voice_capture/audio/audio_diag_log.dart` (+1/−42).

So 195's unique surface is far smaller than its 94-file diff suggests: **11 divergent
files whose correct version I cannot determine mechanically, plus one 3-line delta.**
The 11 are not one-directional — 195 is larger on `capture_pipeline_service.dart`
(+1300/−93) and on `remote_processing_consent_copy.dart` (+34/−1), but much smaller on
`app_services.dart` (+30/−650) and `record_pipeline_log.dart` (+1/−99). **These need a
human to read. I am explicitly not confident which side is correct.**

**PR 197** (116 files) — `split/main-gates-budget`.

| Group | Count | Disposition |
|---|---|---|
| Byte-identical to stack B | 83 | nothing to preserve |
| Adds that PR 198 immediately deletes | 23 | `tool/archive/run_*_gate.sh` etc. Absent from stack B's `apps/mobile/tool/archive/`; they exist in stack B only under `apps/voicememory_mobile/tool/`. 197 adds them, 198 removes them — net zero. Not worth preserving. |
| Deletions that are no-ops vs stack B | 3 | `tool/validate_{mobile_privacy_logs.dart,production_route_links.dart,v1_production_graph.sh}` — stack B already has these only under `tool/archive/` |
| **Genuinely unique deltas** | 4 | `tool/gates.yaml` (+41 lines over stack B), `tool/run_gate.py` (+2/−1), `tool/archive/validate_core.sh` (+20), `apps/mobile/.gitignore` (+2/−6) |
| **Would revert stack B fixes** | 3 | `tool/run_api_dto_self_test.dart` and `tool/run_pro_status_self_test.dart` carry 175's version, which **PR 190 explicitly fixes** ("stop the self-test gates from passing vacuously"). `tool/restore_lib_features_symlinks.sh` carries 175's version, which **PR 187 fixes**. |

Recommended split for 197: extract only the four unique deltas as a small PR against
stack B. Drop the 23 add-then-delete files, the 3 no-op deletions, and — critically — the
3 files that would undo PRs 187 and 190.

### PRs not in any bucket

- **PR 175, 185, 186, 187, 188, 189, 190, 191** — these *are* stack B. Keep.

---

## 2. Bucket 1 close list, in safe order

`delete_branch_on_merge` is **false** on this repository, and closing a PR does not delete
its head branch. Verified via `gh api repos/careos-healthcare/voice-memory`. That matters
because three bucket-2/3 PRs are based on branches whose PRs are being closed:

- `split/main-lib-landing` (PR 196) is the base of **197, 200, 201**
- `split/main-mobile-scaffold` (PR 203) is the base of **204**

**Do not delete any branch.** If a branch is deleted, its dependent PRs are auto-retargeted
by GitHub and their diffs change shape without warning.

**Do not run these. They are listed for a human to execute.**

```
# 1 — leaf first, no dependents
gh pr close 198 --comment "Superseded by stack B. Measured against the stack-B tip (PR 187, which contains 175+185+186+187), this PR is a complete no-op: 23 of its 26 files delete paths that exist in no stack-B branch and in no main tree — they exist only because PR 197 creates them two commits earlier in this same stack — and the remaining 3 files are byte-identical to stack B. git merge-tree of this PR's delta onto the stack-B tip produces zero output. Closing as duplicate; the gate-cleanup intent is already the state of stack B. Branch is retained."

# 2 — standalone, no dependents
gh pr close 194 --comment "Superseded by PR #175. All 167 files are byte-identical (same blob OID and mode) to PR #175's tree. One of them, apps/mobile/docs/architecture/README.md, is further revised by PR #186 on top of that identical base, so stack B carries a strictly later version. Nothing in this PR is absent from stack B. Closing as duplicate; branch is retained."

gh pr close 193 --comment "Superseded by PR #175. Both files — docs/release/BASELINE_2026-08-12.md and docs/release/FOCUSED_BETA_DECISIONS.md — are byte-identical to PR #175's tree. git merge-tree of this PR's delta onto the stack-B tip produces zero output. Closing as duplicate; branch is retained."

gh pr close 192 --comment "Superseded by PR #175. Both files are byte-identical to PR #175's tree, and independently to PR #176's tree. git merge-tree of this PR's delta onto the stack-B tip produces zero output. Closing as duplicate; branch is retained."

# 3 — base of 197, 200 and 201. Confirm the branch split/main-lib-landing
#     is NOT deleted before or after closing.
gh pr close 196 --comment "Superseded by PR #175. All 1517 files are byte-identical (same blob OID and mode) to PR #175's tree and to the stack-B tip. git merge-tree of this PR's delta onto the stack-B tip produces zero output — git finds nothing to apply. 14 of the 1517 are further revised by PRs #188 and #191 on top of that identical base, so stack B is strictly ahead. NOTE: the branch split/main-lib-landing must NOT be deleted — PRs #197, #200 and #201 are based on it and #200/#201 carry work that exists nowhere else. Closing as duplicate."

# 4 — LAST, and only after PR 204 has been retargeted or its content captured
gh pr close 203 --comment "Superseded by PR #185. All 117 files are byte-identical to PR #185's diff. PR #185 additionally carries packages/archiveme_research/pubspec.yaml, which this PR lacks; there is no file here that #185 does not have, and no divergence. git merge-tree of this PR's delta onto the stack-B tip produces zero output. NOTE: the branch split/main-mobile-scaffold must NOT be deleted — PR #204 is based on it and deletes 7,377 files that exist nowhere else. Closing as duplicate."
```

**PR 203 is the one sequencing trap in this list.** PR 204 (bucket 2, 7,377 unique
deletions) is based on 203. Closing 203's *pull request* is harmless as long as the branch
survives, but 204 would then be targeting a branch that will never merge. Retarget 204
onto stack B (a `gh pr edit --base` write, out of scope here) **before** closing 203, or
accept that 204 has to be reconstructed later.

---

## 3. Preserving buckets 2 and 3

Every conflict figure below is from `git merge-tree <PR-merge-base> origin/split/analyzer-excludes-symlinks <PR-head>`.

| PR | Target base | Expected conflicts | How |
|----|-------------|--------------------|-----|
| 202 | `main` **or** stack B | none | Stands alone. Stack B's root `.gitignore` is byte-identical to `main`'s, so this applies either way. Land first — zero interaction with anything. |
| 199 | `main` **or** stack B | none | Stands alone. All 29 targets present in both trees. |
| 201 | stack B, after 186 | none | Retarget from `split/main-lib-landing` to stack B. 1149/1154 blobs are new. **Highest-value item to preserve.** |
| 204 | stack B, after 186 | none | Retarget from `split/main-mobile-scaffold`. Deletes exactly the 7,377 files stack B still carries. See CI caveat in §7 — the `flutter-gates` job runs `working-directory: apps/voicememory_mobile` on `main`, so 204 breaks that job unless stack B's workflow rewrite lands first. |
| 200 | stack B, after 186 | none | Retarget. 74 of 75 files are real changes. |
| 120 | `main`, then rebase | 1 add/add on `apps/voicememory_mobile/APP_STORE_SUBMISSION_PACK.md` | Manual resolution. Then note that PR 204 deletes the entire tree 120 adds to — these two annihilate each other. Decide which you want before spending effort. |
| 173 | orphan | n/a | Base branch has no open PR. Either open a PR for `cursor/batch9-research-evaluation-598e` or retarget 173 at `main`. |
| **195** | split required | 11 add/add, 84 conflict hunks | Split: drop the 66 identical + 2 stale-variant + 12 symlink-shadowed + 2 relocated files. What remains needing decisions is 11 divergent files and `tool/validate_v1_production_graph.sh`. **Human review required — see §1 bucket 3.** |
| **197** | split required | 5 add/add, 10 conflict hunks | Split: keep only `tool/gates.yaml`, `tool/run_gate.py`, `tool/archive/validate_core.sh`, `apps/mobile/.gitignore` as a delta on top of stack B. Explicitly drop the 3 files that would revert PRs 187 and 190. |
| 176–184 | stack B, then rebase | 176 → 110 add/add; 177 → 21 add/add, 129 hunks; 183 → 5 add/add | Stack A must be rebased after stack B lands. It also shadows stack B's symlinks at `lib/features/{archive_search,journal,memory}` — and all 3 of those files are byte-identical to stack B's `retired_sprawl` copies, so those three collisions can simply be dropped. |

**Recommended order.**

```
1.  202, 199                      standalone, zero conflict, land any time
2.  175 → 185 → 186               MANDATORY as a unit (see §4)
3.  187, 190, 188, 191, 189       remaining stack B, any order after 186
4.  201, 204, 200                 retarget onto stack B, land clean
5.  197-split, 195-split          after human review
6.  176 → 177 → …                 stack A, rebased
7.  120                           after deciding 120-vs-204
```

---

## 4. Is stack B internally coherent?

**No. Its intermediate states are broken, and the breakage is real.**

Verified by reading every `120000`-mode entry out of each tree, resolving each symlink
target against the set of paths and directories present in that same tree:

| Ref | Symlinks total | Under `lib/features/` | Resolvable | Dangling | `retired_sprawl/` files tracked |
|---|---|---|---|---|---|
| `main` | 35 | 0 | — | 0 | 0 |
| **175** | 408 | 373 | 0 | **373** | 0 |
| **185** | 409 | 373 | 0 | **373** | 0 |
| 186 | 409 | 373 | **373** | 0 | 2286 |
| 187 | 409 | 373 | 373 | 0 | 2286 |

The prior inventory's claim is confirmed exactly: **373 of 373 dangling at PR 175, and it
is PR 175 — not 186 or 187 — that creates all of them.**

**What merging 175 alone would produce.** `main` would gain 373 symlinks under
`apps/mobile/lib/features/` pointing at `../../retired_sprawl/lib_features/<name>`, a
directory that does not exist. Every Dart import resolving through those paths fails. The
Flutter analyzer and any `flutter test` run break immediately. And because PR 175 targets
`main` directly and is `MERGEABLE`, nothing in GitHub's UI prevents this. **PR 185 does not
fix it either** — 185 is 118 files of iOS/Android/Linux scaffolding and leaves all 373
dangling. Only PR 186, two levels down, supplies the targets.

**Required merge order.** `175 → 185 → 186` is mandatory and must be treated as a single
atomic landing. 187 requires 186 (it excludes `retired_sprawl` from the analyzer).
188, 189, 190 and 191 branch off 175 directly, so they can technically land at any point
after 175 — but landing any of them while `main` is in the 175-only state leaves `main`
broken, so they should also wait for 186.

Beyond that ordering constraint, stack B is coherent: 188/189/190/191 do not conflict with
each other (they touch disjoint paths apart from `tool/gates.yaml`, which 188 and 190 both
edit — that one needs attention), and B-final is a well-formed 15,187-path tree.

---

## 5. Where today's work actually lands

**Snapshot as of the end of this analysis; the tree is moving.**

HEAD is `cc346da9` = PR 175's tip. The index has been heavily staged: 3,866 paths staged
as adds, 9,218 tracked paths deleted in the worktree, 1,589 untracked files. Notably, most
of PR 185's and PR 186's content is already `git add`ed into the index on top of 175.

The symlink premise is confirmed. `apps/mobile/lib/features/{caregiver,privacy,trust,voice_capture}`
are mode-`120000` symlinks, so edits "in" those paths physically land under
`apps/mobile/retired_sprawl/lib_features/`.

**But the reported counts are wrong**, and wrong in a way that matters. The inventory's
"12 of 12 caregiver, 5 of 5 privacy, 2 of 12 trust, 18 of 32 voice_capture" is a
**filesystem-mtime** count of recently-touched files. A content comparison against PR 186's
actual blobs gives very different numbers.

### Modifications to files inside PR 186 — exactly 25 files

`git diff --name-status origin/split/retired-sprawl-tracked -- apps/mobile/retired_sprawl`:

```
apps/mobile/retired_sprawl/lib_features/archive_beliefs/archive_beliefs_presenter.dart
apps/mobile/retired_sprawl/lib_features/archive_beliefs/belief_change_timeline.dart
apps/mobile/retired_sprawl/lib_features/capture_flow/adapters/journal_transcript_correction_adapter.dart
apps/mobile/retired_sprawl/lib_features/capture_flow/adapters/pipeline_capture_adapters.dart
apps/mobile/retired_sprawl/lib_features/capture_flow/capture_flow_controller.dart
apps/mobile/retired_sprawl/lib_features/capture_flow/capture_flow_dependencies.dart
apps/mobile/retired_sprawl/lib_features/capture_flow/capture_flow_phase.dart
apps/mobile/retired_sprawl/lib_features/capture_flow/interfaces/capture_flow_ports.dart
apps/mobile/retired_sprawl/lib_features/capture_flow/ui/capture_screen.dart
apps/mobile/retired_sprawl/lib_features/caregiver/caregiver_copy.dart
apps/mobile/retired_sprawl/lib_features/caregiver/caregiver_mode_controller.dart
apps/mobile/retired_sprawl/lib_features/caregiver/caregiver_models.dart
apps/mobile/retired_sprawl/lib_features/caregiver/caregiver_read_service.dart
apps/mobile/retired_sprawl/lib_features/consent_audit/consent_audit_service.dart
apps/mobile/retired_sprawl/lib_features/consent_audit/consent_revocation_store.dart
apps/mobile/retired_sprawl/lib_features/contradiction_detection/statement_analysis.dart
apps/mobile/retired_sprawl/lib_features/export/journal_bulk_export_service.dart
apps/mobile/retired_sprawl/lib_features/privacy/on_device_processing_store.dart
apps/mobile/retired_sprawl/lib_features/privacy/privacy_security_control_center_copy.dart
apps/mobile/retired_sprawl/lib_features/privacy/privacy_security_trust_copy.dart
apps/mobile/retired_sprawl/lib_features/privacy_trust/privacy_trust_copy.dart
apps/mobile/retired_sprawl/lib_features/timeline/timeline_entry_display.dart
apps/mobile/retired_sprawl/lib_features/transcript_correction/transcript_correction_controller.dart
apps/mobile/retired_sprawl/lib_features/trust/trust_reliability_copy.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/native_speech_transcription.dart
```

By directory: caregiver **4** (not 12), privacy **3** (not 5), trust **1**,
voice_capture **1** (not 18), plus 16 in capture_flow / archive_beliefs / consent_audit /
contradiction_detection / export / privacy_trust / timeline / transcript_correction —
directories the inventory did not mention at all. The 2,261 other files in 186's set are
byte-identical to 186.

### Genuinely new paths under `retired_sprawl` — 6 files

```
apps/mobile/retired_sprawl/lib_features/beta_analytics/product_analytics_consent_store.dart
apps/mobile/retired_sprawl/lib_features/capture_flow/ui/local_transcription_unavailable_card.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/local_transcription_availability.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/local_transcription_choice_store.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/local_transcription_unavailable_copy.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/transcription_capability_policy.dart
```

### An index anomaly worth knowing about

12 paths that PR 186 tracks exist on disk but are **not in the index** (`??` in
`git status`), so `git diff` against 186 reports them as deleted. They are exactly the 12
files PR 195 adds under `lib/features/`:

```
retired_sprawl/lib_features/activation/archive_insight_feedback.dart
retired_sprawl/lib_features/billing/application/billing_notifier.dart
retired_sprawl/lib_features/pattern_naming/pattern_name_store.dart
retired_sprawl/lib_features/proof_admission/remote_processing_{consent_store,data_flow,purpose}.dart
retired_sprawl/lib_features/recording/recording_state_controller.dart
retired_sprawl/lib_features/trust/privacy_screen_copy.dart
retired_sprawl/lib_features/voice_capture/analysis/analysis_log.dart
retired_sprawl/lib_features/voice_capture/audio/audio_diag_log.dart
retired_sprawl/lib_features/voice_capture/transcription/provisional_transcript_reconciler.dart
retired_sprawl/lib_features/voice_capture/transcription/transcription_log.dart
```

Anyone committing today's work with `git add -A` will produce a commit that *deletes*
these 12 from 186's set unless they are staged. This is a live footgun.

### Modifications to files inside PR 175 — 80 modified, 12 deleted

80 of PR 175's tracked files under `apps/mobile/{lib,test,tool,docs}` are modified in the
worktree, and 12 are deleted. The deletions are the ObjectBox removal
(`lib/objectbox.g.dart`, `lib/objectbox-model.json`, `lib/features/search/data/*`) plus
consent-panel and belief-evidence files. Full lists in `/tmp/vpart/wt_vs_175.txt`.

Also modified inside PR 185's set: 6 files —
`android/.../NativeSpeechTranscription.kt`, `ios/Podfile`, `ios/Podfile.lock`,
`ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/IosNativeSpeechTranscription.swift`,
and `pubspec.yaml`.

### What this means for slicing

Today's mobile work is overwhelmingly **modification of files inside three already-open
PRs** (175, 185, 186), not new-file work. A new PR containing these edits cannot target
`main` — the files do not exist there. It must be stacked on 186 (for the retired_sprawl
edits) or on 175/185 (for the rest), or all of it must be folded into those PRs directly.

---

## 6. `pubspec.yaml` / `pubspec.lock`

Measured by blob OID at every relevant ref:

| Ref | `apps/mobile/pubspec.yaml` | `apps/mobile/pubspec.lock` |
|---|---|---|
| `main` | **absent** | **absent** |
| 175 (B) | **absent** | **absent** |
| 176 (A) | absent | absent |
| 195, 196 (C) | **absent** | **absent** |
| **185, 186, 187 (B)** | `2e82bcd2` | `d19bf458` |
| **203, 204 (C)** | `2e82bcd2` | `d19bf458` |
| 177, 184 (A) | `177ce4f0` | `9552e11e` / `1bce588c` |
| 179 (A) | `961e794f` | `258d99da` |
| worktree | `4a5e9520` | `d19bf458` |

**The correct version for stack B is PR 185's: `pubspec.yaml` = `2e82bcd2`,
`pubspec.lock` = `d19bf458`.**

**Correction to the reported problem.** Stack B and stack C do **not** diverge on these
files — 185 and 203 carry byte-identical copies, which is unsurprising given 203 is a
byte-for-byte re-slice of 185. The divergence is **stack A only**: PRs 177, 179 and 184
each carry a different manifest. That is also the correct diagnosis of PR 179's conflict —
it conflicts with its own parent `split/journal-sqlite-core` (PR 177), both stack A, on
exactly these two files (2 "changed in both", 2 conflict hunks). It has nothing to do with
stack B or C. The inventory's framing of this as spanning "all three stacks" is
technically true of the set `{177, 179, 185, 203}` but misleading about where the tension is.

**The stale-lockfile problem is real.** Today's edit removed ObjectBox from the manifest:

```
-  objectbox: ^5.3.2
-  objectbox_flutter_libs: ^5.3.2
-  objectbox_generator: ^5.3.2
```

The worktree `pubspec.yaml` is now `4a5e9520`, but `pubspec.lock` is still `d19bf458` —
byte-identical to stack B's, i.e. untouched. **The lockfile still pins ObjectBox packages
the manifest no longer declares.** No `pub get` has been run (and per the constraints,
none was run here).

**Resolution for stack B.** Take 185's `pubspec.yaml` as the base, apply the three ObjectBox
removals on top, then regenerate `pubspec.lock` with a real `flutter pub get` *before*
committing. Committing the current pair would land a manifest/lockfile mismatch on stack B,
and `flutter-gates` would be the first thing to notice.

---

## 7. Which PRs have real CI coverage

**Confirmed, and the problem is larger than reported.**

`main` carries exactly one workflow, `.github/workflows/archiveme-stabilization.yml`,
whose trigger is:

```yaml
on:
  push:
    branches: [main, 'cursor/**']
  pull_request:
    branches: [main]
```

PR 175 adds a second, `.github/workflows/ci.yml`, gated the same way
(`pull_request: branches: [main, master]`). **Both key on the PR's base branch.** A PR
whose base is not `main` runs neither.

Measured with `gh pr checks` across all 32 PRs:

| Check profile | Count | PRs |
|---|---|---|
| Full suite (8–10 checks) | **8** | 175, 176, 192, 193, 194, 195, 199, 202 — all target `main` |
| **Vercel only (2 checks)** | **24** | 173, 177–191, 196, 197, 198, 200, 201, 203, 204 |
| Conflicted, Vercel only | — | 120 |

**Correction to the inventory.** It said "the seven PRs showing clean are running 2 checks
versus the 8–10 on main-targeted ones," implying the vacuous-green problem is confined to
stack C. It is not. **All of stack B's children — 185, 186, 187, 188, 189, 190, 191 — also
run only the two Vercel checks**, as do all of stack A's children. 24 of 32 PRs have no
gate coverage at all. The stack-C PRs merely *look* better because Vercel happens to pass
on them, while it fails on stack A and B; `Vercel` fails on 19 PRs including one-file
documentation changes, so it is environmental noise either way.

**Which of stack B would actually be validated if merged.** Only **PR 175**, because it is
the only stack-B PR whose base is `main`. And 175 currently fails 5 of its 10 checks:
`flutter-gates`, `server-gates`, `Backend Typecheck & QA`, `Flutter Mobile Build & Test`,
and `Vercel`. PRs 185–191 would merge into `main` with **zero gate evidence** — and 186 is
the 2,287-file commit that makes 373 symlinks resolve.

**A CI trap for PR 204.** On `main`, the `flutter-gates` job runs with
`working-directory: apps/voicememory_mobile` — the exact tree PR 204 deletes. Stack B's
version of the same workflow (from PR 175) points at `apps/mobile`. So 204 must land after
stack B's workflow rewrite, or `flutter-gates` fails on a missing working directory.

---

## 8. Highest-risk concern about executing this plan

**The plan's correctness depends on stack B being landed in one atomic sequence, and
nothing in GitHub enforces that.**

PR 175 is `MERGEABLE` against `main` and its merge button is live. Merging it alone puts
373 dangling symlinks on `main`, and the fix (PR 186) is two levels below it in the stack
and carries no CI coverage of its own. Between 175 landing and 186 landing, `main` cannot
analyze, cannot test, and cannot build the mobile app — and in that window every other
open PR's mergeability is recomputed against a broken tree. If someone merges 175 on a
Friday and stops, the recovery is not a revert of one PR; it is a revert of a 2,802-file
commit that eleven agents have been building on top of all day.

This outranks the duplicate-closure risk because the closures are reversible (a closed PR
can be reopened, and `delete_branch_on_merge` is false so no branch is lost) while a broken
`main` in a repository with eleven concurrent writers is not.

The second-order version of the same concern: **I cannot verify that the working tree
state I measured is the state that gets committed.** The worktree changed by 6 status
entries during this analysis, and 12 files that PR 186 tracks are currently untracked in
the index. A `git add -A` commit right now would delete them from 186's set.

---

## 9. Claims in `/tmp/OPEN_PR_INVENTORY.md` that I checked and found wrong

| Claim | Where | Finding |
|---|---|---|
| "PR 194's entire content is already inside PR 175, 167 files byte-identical." | §4d, §6 | **Correct but self-contradicted.** §4c of the same document lists `apps/mobile/docs/architecture/README.md` as divergent across 175/186/194. Both are true of different reference points — 194 == 175 exactly; 186 revises it afterwards — but the document asserts them as if they were the same comparison. |
| "The seven PRs showing clean are running 2 checks versus 8–10 on main-targeted ones." | §1, §10 | **Understated.** 24 of 32 PRs run only 2 checks, not 7. Stack B's own children (185–191) are in that set. |
| "`pubspec.lock` / `pubspec.yaml` carry divergent copies in four or five PRs across all three stacks." | §4b, §10 | **Misleading.** 185 (stack B) and 203 (stack C) are byte-identical on both files. Neither file exists in `main`, 175, 176, 195 or 196. The divergence is confined to stack A (177, 179, 184), which is also the actual cause of PR 179's conflict. |
| "12 of 12 caregiver files, 5 of 5 privacy, 2 of 12 trust, 18 of 32 voice_capture recently modified under retired_sprawl." | §7 | **Wrong metric.** These are filesystem-mtime counts. Content-compared against PR 186's blobs, the real figures are caregiver 4, privacy 3, trust 1, voice_capture 1 — 25 modified files in total, spread across 11 directories including several the table does not mention. |
| "Today's caregiver/privacy/trust/voice_capture work … will conflict with [PR 186] directly." | §7 | **Overstated.** 25 files modify 186's set; the other 2,261 are byte-identical. Six new paths are added. It is a small delta on a large PR, not a broad conflict. |
| "PR 203 is a duplicate of PR 185. 117 of 185's 118 files … the only file 185 has that 203 lacks is `packages/archiveme_research/pubspec.yaml`." | §6 | **Verified correct**, including that no shared path diverges. |
| "PR 196's 1517 files are byte-identical inside PR 175." | §4d, §10 | **Verified correct.** Independently confirmed by `merge-tree` producing zero output. |
| "All 373 symlinks are dangling in PR 175's own tree … 373/373 at 175, 0/373 at 186." | §8 | **Verified correct**, and PR 185 is also 373/373 dangling. |
| Not stated anywhere | — | **The largest omission.** PR 201 carries 1,149 blobs that exist in no stack-B branch — the entire `apps/mobile/test/` suite. The inventory lists 201 only as a stack-C member with 1154 files and never distinguishes it from the re-slices. A wholesale stack-C closure would have destroyed it. |
| Not stated | — | PR 195's twelve `lib/features/` additions are 8 byte-identical to and 4 strictly thinner than stack B's copies of the same files behind the symlinks. The inventory listed them as "colliding" without checking whether the content already existed in stack B. |
| Not stated | — | PR 197 carries versions of `run_api_dto_self_test.dart`, `run_pro_status_self_test.dart` and `restore_lib_features_symlinks.sh` that predate the fixes in PRs 190 and 187. Landing 197 unsplit would revert two stack-B bug fixes. |

I also found and corrected a **methodological** error that was mine, not the inventory's,
but which any repeat of this analysis will hit: `git diff --raw` abbreviates blob OIDs, and
comparing those to `ls-tree` output silently yields zero matches everywhere. The inventory's
own figures are internally consistent, so it did not make this mistake.

**Not checked.** I did not re-verify the inventory's aggregate overlap counts (2,195
multi-PR paths, 1,957 identical, 238 divergent), the 212-file cross-stack divergent list in
§4c beyond the entries relevant to bucket assignment, or PR 189's LFS content. I did not
open any CI logs, so I cannot say why `Vercel` fails on 19 PRs.

---

## 10. Read-only attestation

**No git write command and no `gh` mutation was run. No file in the repository was
created, modified, or deleted.**

Git commands used, all read-only: `rev-parse`, `remote -v`, `ls-remote`, `merge-base`,
`diff` (`--raw`, `--name-status`, `--numstat`, `--stat`, and against the working tree),
`ls-tree`, `cat-file -p`, `hash-object` (without `-w`, which computes an OID and writes
nothing), `status --porcelain`, `show`, `--version`, and `merge-tree` in its
three-argument non-writing form only.

`gh` usage: `gh pr list --json`, `gh pr checks`, and `gh api repos/... --jq` — all reads.

No `git fetch` was performed; local remote-tracking refs were verified current against
`git ls-remote origin` instead (34 refs, 0 mismatches).

`apps/mobile/tool/restore_lib_features_symlinks.sh` was **not** executed. No `flutter`,
`dart pub get`, `npm install`, or build command was run.

All scratch output is under `/tmp/vpart/`: `prdiffs.json`, `trees_B.json`,
`classify.json`, `classify_detail.json`, `detail1.txt`, `detail2.txt`, `detail3.txt`,
`mergetree.txt`, `mt_<pr>.txt`, `wt_vs_186.txt`, `wt_vs_175.txt`, `status_all.json`,
`checks.txt`. This report is `/tmp/PR_PARTITION_PLAN.md`.
