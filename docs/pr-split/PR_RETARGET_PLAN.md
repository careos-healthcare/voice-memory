# PR Re-target Plan — voice-memory

Read-only analysis, 2026-08-22 17:30–17:46 local. Verifies and corrects
`/tmp/PR_PARTITION_PLAN.md` and `/tmp/OPEN_PR_INVENTORY.md`.

**No git write command and no `gh` mutation was run. No repository file was created,
modified or deleted.** Full attestation in §11.

---

## 0. The headline, before anything else

**`gh pr edit --base` cannot do what this plan needs it to do, for any of 197, 200, 201
or 204.** Re-targeting those PRs onto stack B changes their displayed diff by *nothing at
all*, because of the commit topology:

```
origin/main = 69121fb1ab0c   (verified current against git ls-remote)

merge-base(origin/main,                             origin/split/main-mobile-test-suite) = 69121fb1
merge-base(origin/archive-me/focused-beta-stabilization, "                            ) = 69121fb1
merge-base(origin/split/mobile-project-scaffold,         "                            ) = 69121fb1
merge-base(origin/split/retired-sprawl-tracked,          "                            ) = 69121fb1
merge-base(origin/split/analyzer-excludes-symlinks,      "                            ) = 69121fb1
```

`origin/main` is an ancestor of every stack-B *and* every stack-C branch, and the two
stacks share no other commit. So the merge base collapses to `main` at **all five
candidate bases**, and the PR's diff is identical at all five.

Measured file counts of the resulting diff, per head, at every candidate base:

| PR | diff at its current base | diff at **any** of the 5 candidates |
|---|---|---|
| 197 | 116 | **1710** |
| 200 | 75 | **1675** |
| 201 | 1154 | **2754** |
| 204 | 7377 | **9094** |

For 201 the decomposition is exact: `195 (94) ∪ 196 (1517) ∪ 201 (1154)` with an 11-file
overlap between 195 and 196 → 2754. Every stack-C branch is a linear chain that contains
195's four commits and 196's three commits:

```
5e8ae304 test(mobile): track the apps/mobile test suite      <- PR 201's own commit
64b8b5d9 feat(mobile): land lib UI layer                     |
3fd7ba0c feat(mobile): land lib infrastructure layer         |  PR 196
3c309ee9 feat(mobile): land V1 feature modules               |
73df601e fix(mobile): enforce production route-link integrity|
af0b6340 fix(mobile): add release-safe logging boundary      |  PR 195
81208811 fix(mobile): migrate personal prefs to encrypted    |
177993da fix(mobile): enforce purpose-specific consent       |
```

Re-targeting keeps the head branch exactly as-is; it only changes what GitHub merges
into. So a re-targeted 201 would **re-land all of 195 and 196 on top of stack B**.

**The correct operation is a cherry-pick of the single relevant commit onto a new branch
cut from stack B, then a new PR.** That is a write and is out of scope here; the exact
commits to pick are named in §2.

---

## 1. Per-PR conflict set at each candidate base, and the effective-diff delta

### Method, and why it differs from the prior analysis

`/tmp/PR_PARTITION_PLAN.md` §3 probed conflicts with
`git merge-tree <PR-merge-base> <stack-B-tip> <PR-head>` where `<PR-merge-base>` was
`merge-base(origin/split/main-lib-landing, head)` = `64b8b5d9`. That base **already
contains 195 and 196**, so the simulation asks "what if only this PR's own delta is
applied to a tree that already has stack C in it" — which is not the merge that would
happen. The correct merge base for merging the branch into stack B is `69121fb1`.

I ran both. I also computed the three-way outcome per path directly from
`git ls-tree`, because `git merge-tree`'s old three-argument form **does not report
file/directory conflicts** — see the box below.

### The conflict the old `merge-tree` does not report

Stack B holds `apps/mobile/lib/features/{activation,billing,pattern_naming,
proof_admission,recording,trust,voice_capture}` as mode-`120000` **symlinks**. Every
stack-C head tree holds **regular files inside** those same seven paths. A git tree
cannot contain both a blob at `X` and a tree at `X`, so this is an unavoidable
file/directory conflict in any real merge.

`git merge-tree 69121fb1 origin/split/analyzer-excludes-symlinks origin/split/main-mobile-test-suite`
reports **0 `added in both` and 0 conflict hunks**, yet its own output contains, in the
same run:

```
  our    120000 825593cc  apps/mobile/lib/features/activation
  their  100644 f90e04b2  apps/mobile/lib/features/activation/archive_insight_feedback.dart
```

It classifies these as two unrelated paths ("added in local" ×7, "added in remote" ×1169)
and declares the merge clean. **The prior analysis's headline "201 → 0 conflicts onto
stack B" is an artifact of this blind spot.** The seven collisions are present at every
stack-B candidate base and absent only at `main`.

### The matrix

Rows are candidate bases. `add/mod/del` = paths the merge would add to, change in, or
delete from that base. `chg-both` = paths where a three-way *text* merge is required
(upper bound on textual conflicts). `f/d` = file-vs-directory collisions.

**PR 201 — `split/main-mobile-test-suite`**

| candidate base | add | mod | del | chg-both | f/d | imports unresolved |
|---|---|---|---|---|---|---|
| `main` | 2753 | 1 | 0 | 0 | **0** | 1779 / 2731 |
| `archive-me/focused-beta-stabilization` | 1169 | 0 | 0 | 0 | **7** | 1785 / 2731 |
| `split/mobile-project-scaffold` | 1169 | 0 | 0 | 0 | **7** | 1785 / 2731 |
| **`split/retired-sprawl-tracked`** | 1169 | 0 | 0 | 0 | **7** | **3 / 2731** |
| `split/analyzer-excludes-symlinks` | 1169 | 0 | 0 | 0 | **7** | **3 / 2731** |
| B-final (187 + 188/189/190/191) | 1169 | 0 | 0 | **16** | **7** | 0 / 2731 |

**PR 200 — `split/main-research-repoint`**

| candidate base | add | mod | del | chg-both | f/d | imports unresolved |
|---|---|---|---|---|---|---|
| `main` | 1600 | 75 | 0 | 0 | **0** | 584 / 584 |
| `archive-me/focused-beta-stabilization` | 16 | 74 | 0 | 0 | **7** | 376 / 584 |
| `split/mobile-project-scaffold` | 16 | 73 | 0 | 0 | **7** | 376 / 584 |
| **`split/retired-sprawl-tracked`** | 16 | 73 | 0 | 0 | **7** | **0 / 584** |
| `split/analyzer-excludes-symlinks` | 16 | 73 | 0 | 0 | **7** | **0 / 584** |
| B-final | 16 | 73 | 0 | **16** | **7** | 0 / 584 |

**PR 204 — `split/main-retire-voicememory-mobile`**

| candidate base | add | mod | del | chg-both | f/d |
|---|---|---|---|---|---|
| `main` | 1716 | 1 | 7377 | 0 | **0** |
| `archive-me/focused-beta-stabilization` | 131 | 0 | 7377 | **1** (`apps/mobile/.gitignore`) | **7** |
| **`split/mobile-project-scaffold`** | 15 | 0 | 7377 | **0** | **7** |
| `split/retired-sprawl-tracked` | 15 | 0 | 7377 | **0** | **7** |
| `split/analyzer-excludes-symlinks` | 15 | 0 | 7377 | **0** | **7** |
| B-final | 15 | 0 | 7377 | **16** | **7** |

**PR 197 — `split/main-gates-budget`**

| candidate base | add | mod | del | chg-both | f/d | merge-tree add/add | merge-tree hunks |
|---|---|---|---|---|---|---|---|
| `main` | 1708 | 2 | 0 | 0 | **0** | 0 | 0 |
| `archive-me/focused-beta-stabilization` | 35 | 0 | 0 | 3 | **7** | 3 | 6 |
| `split/mobile-project-scaffold` | 35 | 0 | 0 | 4 | **7** | 4 | 7 |
| `split/retired-sprawl-tracked` | 35 | 0 | 0 | 4 | **7** | 4 | 7 |
| `split/analyzer-excludes-symlinks` | 35 | 0 | 0 | 5 | **7** | 5 | 10 |
| B-final | 35 | 0 | 0 | **23** | **7** | — | — |

The 16 `chg-both` paths that appear only at B-final are identical for 200, 201 and 204 —
they are inherited from 195/196 colliding with 188 and 191, not from the PR's own work:

```
lib/features/belief_changes/belief_change_moment_engine.dart          (vs 191)
lib/features/belief_changes/ui/belief_change_pattern_card.dart        (vs 191)
lib/features/belief_evidence/ui/belief_evidence_insight_card.dart     (vs 191)
lib/features/belief_evidence/ui/evidence_trust_copy.dart              (vs 191)
lib/features/belief_evidence/ui/view_source_proof_section.dart        (vs 191)
lib/features/fact_ledger/fact_ledger_citation_service.dart            (vs 191)
lib/features/insights/archive_insights_engine.dart                    (vs 191)
lib/features/onboarding/ui/onboarding_v1_copy.dart                    (vs 188)
lib/features/onboarding/ui/remote_processing_consent_copy.dart        (vs 188)
lib/features/onboarding/ui/remote_processing_consent_step.dart        (vs 188)
lib/security/privacy_copy_policy.dart                                 (vs 188)
lib/ui/screens/settings/privacy_security_screen.dart                  (vs 188)
lib/widgets/archive/archive_insight_card.dart                         (vs 191)
lib/widgets/settings/privacy_security_trust_section.dart              (vs 188)
test/remote_processing_consent_copy_test.dart                         (vs 188)
test/support/release_suite_static_state_reset.dart                    (vs 191)
```

197 adds seven more of its own at B-final: `apps/mobile/.gitignore`,
`tool/archive/validate_core.sh`, `tool/gates.yaml`, `tool/restore_lib_features_symlinks.sh`,
`tool/run_api_dto_self_test.dart`, `tool/run_gate.py`, `tool/run_pro_status_self_test.dart`.

### Effective-diff delta: what re-targeting silently gains

The 15 paths a re-targeted 201/200/204 would add to stack B **that are not its own work**
are identical in all three cases, and are 195's contribution:

```
apps/mobile/lib/features/activation/archive_insight_feedback.dart                        <- destroys symlink
apps/mobile/lib/features/billing/application/billing_notifier.dart                       <- destroys symlink
apps/mobile/lib/features/pattern_naming/pattern_name_store.dart                          <- destroys symlink
apps/mobile/lib/features/proof_admission/remote_processing_consent_store.dart            <- destroys symlink
apps/mobile/lib/features/proof_admission/remote_processing_data_flow.dart                <- destroys symlink
apps/mobile/lib/features/proof_admission/remote_processing_purpose.dart                  <- destroys symlink
apps/mobile/lib/features/recording/recording_state_controller.dart                       <- destroys symlink
apps/mobile/lib/features/trust/privacy_screen_copy.dart                                  <- destroys symlink
apps/mobile/lib/features/voice_capture/analysis/analysis_log.dart                        <- destroys symlink
apps/mobile/lib/features/voice_capture/audio/audio_diag_log.dart                         <- destroys symlink
apps/mobile/lib/features/voice_capture/transcription/provisional_transcript_reconciler.dart <- destroys symlink
apps/mobile/lib/features/voice_capture/transcription/transcription_log.dart              <- destroys symlink
apps/mobile/tool/validate_mobile_privacy_logs.dart
apps/mobile/tool/validate_production_route_links.dart
apps/mobile/tool/validate_v1_production_graph.sh
```

Replacing those seven symlinks with directories containing one to four files each is
exactly the silent-corruption mode `OPEN_PR_INVENTORY.md` §10 warned about: it would make
the 2,286 files under `apps/mobile/retired_sprawl/lib_features/` unreachable at the paths
the app imports, for those seven features.

---

## 2. Recommended base per PR, and the ordered command list

### Recommendations

| PR | Recommendation | Confidence |
|---|---|---|
| **201** | **Preserve.** Base must be `split/retired-sprawl-tracked` or deeper. **Do not `gh pr edit --base`** — cherry-pick `5e8ae304` instead. | High |
| **200** | **Preserve.** Base must be `split/retired-sprawl-tracked` or deeper. Cherry-pick `8db59f78`. | High |
| **204** | **Preserve.** Shallowest safe base `split/mobile-project-scaffold`; recommend `split/analyzer-excludes-symlinks`. Cherry-pick `63c66fa5`. | High |
| **197** | **Close. It has no durable unique content at all.** See §4. | High |
| **195** | Keep open for now, but its only durable content is one file. See §5. | Medium |

### PR 201 — `split/main-mobile-test-suite`

*Base is hard-constrained to #186 or deeper, by imports.* Its 1,147 Dart test files carry
9,267 `package:archiveme_mobile/...` import statements against 2,731 distinct targets:

| base | distinct import targets that resolve | unresolved |
|---|---|---|
| `split/main-lib-landing` (**its current base**) | 952 | **1779** |
| `archive-me/focused-beta-stabilization` (#175) | 946 | **1785** |
| `split/retired-sprawl-tracked` (#186) | **2728** | **3** |

908 of 1,147 test files import through at least one of the 373 symlinked feature
directories, referencing 338 distinct ones. Stack C's #196 supplies only **20** feature
directories as regular files; #186 supplies **338** of the referenced 351 via
`retired_sprawl`. At #175 and #185 the symlinks all dangle, so those bases fail too.

Two consequences worth stating plainly:

1. **This test suite does not compile against its own current base.** 65% of its imports
   are unresolvable at `split/main-lib-landing`. Its green CI is the two Vercel checks,
   which do not build Flutter.
2. The three imports still unresolved at #186 are
   `features/belief_evidence/ui/view_source_proof_sheet.dart` (supplied by **#191**),
   `features/auth/domain/caregiver_access_copy.dart` and
   `features/settings/ui/caregiver_access_screen.dart` (**present only in today's
   uncommitted working tree**). So 201's tests were generated against a tree that already
   had today's caregiver work — they resolve fully only at B-final *plus* today's changes.

### PR 200 — `split/main-research-repoint`

Also hard-constrained to #186 or deeper, by the same mechanism: its 71 Dart files carry
584 distinct `package:archiveme_mobile/...` targets, of which **584/584 resolve at #186
and only 209 at its current base**. `packages/archiveme_research/pubspec.yaml` in 200
declares `archiveme_mobile: path: ../../apps/mobile`, and the package imports
`features/capacity_loop` (71), `features/pressure_retention` (33), `features/activation`
(32) and many more — all symlinked directories that only resolve once #186 lands.

74 of its 75 files are real changes against stack B; the 75th
(`packages/archiveme_research/pubspec.yaml`) is byte-identical to #185's copy.
`packages/archiveme_research` already exists on `main` with 76 files, so no scaffolding
dependency. Zero content conflicts at every candidate base.

### PR 204 — `split/main-retire-voicememory-mobile`

Pure deletion: 7,377 files, 100% under `apps/voicememory_mobile/`, no imports, no
resolution constraint. Its base depth is set by one file:

- At **#175** there is one `changed in both` on `apps/mobile/.gitignore` (175's
  `fc344ebf` vs 204's `a8473454`).
- At **#185 and deeper** that conflict disappears, because #185 is where `a8473454`
  comes from.

So the shallowest conflict-free base is `split/mobile-project-scaffold`. I recommend
`split/analyzer-excludes-symlinks` anyway, so the deletion lands after the analyzer
excludes are in place.

**CI constraint, verified.** `main`'s only workflow,
`.github/workflows/archiveme-stabilization.yml`, runs five steps with
`working-directory: apps/voicememory_mobile` — the tree 204 deletes. Stack B's version of
the same workflow (from #175) uses `working-directory: apps/mobile`, and #175 also adds
`.github/workflows/ci.yml` with `working-directory: apps/mobile`. **204 must land after
#175's workflow rewrite**, or `flutter-gates` fails on a missing working directory.

### The command list — DO NOT RUN

Because re-targeting is the wrong operation here, this list is deliberately *not* a set of
`gh pr edit --base` commands for 197/200/201/204. Running those would leave four PRs whose
diffs are 1,675–9,094 files and which structurally cannot merge.

**Safe now — closures with no dependents and no re-derivation needed:**

```sh
# 197 — zero durable content against stack B (see §4). Leaf: its only child, 198,
# is already closed. No re-targeting required first.
gh pr close 197 --comment "Superseded by stack B, with nothing to carry forward. Of 116 files: 83 are byte-identical to stack B; 23 add tool/archive/run_*_gate.sh wrappers that #198 deleted again and whose 20 target test files exist in no branch and in no working tree; 3 delete paths stack B only carries under tool/archive/. Of the remaining 7, tool/gates.yaml, tool/run_gate.py and tool/archive/validate_core.sh are each restored to stack B's exact blob by #198 (7f332ee3, 2064e256, 6b384a34), so 197+198 is a net no-op on all three; and apps/mobile/.gitignore, tool/restore_lib_features_symlinks.sh, tool/run_api_dto_self_test.dart and tool/run_pro_status_self_test.dart all carry #175's blob verbatim, which #185, #187 and #190 respectively supersede. There is no delta here to re-derive. Branch is retained."
```

**Blocked — must NOT be closed until their content is re-based onto stack B:**

```sh
# 196 (split/main-lib-landing) and 203 (split/main-mobile-scaffold) stay OPEN until
# the cherry-picks below exist as new PRs. Closing the PR is harmless while the branch
# survives (delete_branch_on_merge is false, verified), but do not delete the branches:
# GitHub auto-retargets dependents of a deleted branch and silently reshapes their diffs.
```

**The writes that actually preserve the work** (out of scope for this task; listed so the
ordering is unambiguous). Each creates a new branch off stack B and cherry-picks one
commit:

```sh
# 1. after 175 -> 185 -> 186 have landed as a unit
git checkout -b split/b-mobile-test-suite   origin/split/analyzer-excludes-symlinks
git cherry-pick 5e8ae304          # PR 201's 1154 test files, 1149 blobs unique
gh pr create --base split/analyzer-excludes-symlinks --head split/b-mobile-test-suite

# 2.
git checkout -b split/b-research-repoint    origin/split/analyzer-excludes-symlinks
git cherry-pick 8db59f78          # PR 200, 74 of 75 files are real changes
gh pr create --base split/analyzer-excludes-symlinks --head split/b-research-repoint

# 3. LAST — must land after #175's workflow rewrite reaches main
git checkout -b split/b-retire-voicememory  origin/split/analyzer-excludes-symlinks
git cherry-pick 63c66fa5          # PR 204, 7377 deletions
gh pr create --base split/analyzer-excludes-symlinks --head split/b-retire-voicememory

# 4. only once 1-3 exist:
gh pr close 201 ; gh pr close 200 ; gh pr close 204 ; gh pr close 196 ; gh pr close 203
```

I have **not** verified that these three cherry-picks apply cleanly, because doing so
requires writing objects. The three-way analysis in §1 says the content merges without
textual conflict onto `split/analyzer-excludes-symlinks`, and the cherry-pick of a single
commit does not carry 195's twelve symlink-shadowing files, which is the whole point.

**Dependency constraints, marked:**

- `split/main-lib-landing` must survive as a *branch* while 200 and 201 are open.
- `split/main-mobile-scaffold` must survive as a *branch* while 204 is open.
- 204's new PR must merge after #175 (workflow `working-directory` rewrite).
- 201 and 200's new PRs must merge after #186 (import resolution).
- 197 can be closed immediately; nothing depends on it (198 is already closed).

---

## 3. Independent verification of PR 201's 1,149-unique-blob claim

**Confirmed exactly.** Method: `git diff --no-renames --raw --abbrev=40` from
`merge-base(origin/split/main-lib-landing, origin/split/main-mobile-test-suite)` =
`64b8b5d9` to the head, giving 1,154 entries — **all status `A`**, 0 modifications,
0 deletions, 100% under `apps/mobile/test/`. Each post-state blob OID was tested for
membership in the union of every blob OID in all eight stack-B refs (175, 185, 186, 187,
188, 189, 190, 191 — 14,286 distinct OIDs).

```
201 post-state blobs NOT present anywhere in stack B:  1149
201 post-state blobs present somewhere in stack B   :     5
201 paths that exist at the same path in B-final    :     0
```

The five that do exist are PNG screenshot fixtures, all present in stack B only under
`apps/voicememory_mobile/`:

```
apps/mobile/test/failures/subscription_review_preview_isolatedDiff.png
apps/mobile/test/failures/subscription_review_preview_maskedDiff.png
apps/mobile/test/failures/subscription_review_preview_masterImage.png
apps/mobile/test/failures/subscription_review_preview_testImage.png
apps/mobile/test/subscription_review_preview.png
```

Note the stronger fact the prior analysis did not state: **not one of 201's 1,154 paths
exists at the same path in B-final.** Stack B's 45 `apps/mobile/test/` files and 201's
1,154 are disjoint path sets. Losing 201 loses 1,149 blobs outright.

**Is its base constrained by imports? Yes — to `split/retired-sprawl-tracked` (#186) or
deeper.** Evidence in §2. This is the one place where the constraint is not merely
"prefer deeper" but "shallower bases produce a test suite that cannot resolve two thirds
of its imports".

---

## 4. PR 197 — the reverting files, and the recommendation

### There are four reverting files, not three

| File | 197's blob | What stack B has | What it reverts |
|---|---|---|---|
| `apps/mobile/tool/run_api_dto_self_test.dart` | `f20020bf` (= #175's) | `dd8e586a` from **#190** | #190 "Stop the self-test gates from passing vacuously" |
| `apps/mobile/tool/run_pro_status_self_test.dart` | `cd3b312b` (= #175's) | `c262bb09` from **#190** | same |
| `apps/mobile/tool/restore_lib_features_symlinks.sh` | `e7a331cf` (= #175's) | `f2d3860a` from **#187** | #187 "Make analyzer excludes actually exclude retired code" |
| **`apps/mobile/.gitignore`** | `fc344ebf` (= #175's) | `a8473454` from **#185** | #185's cleanup — **missed by the prior analysis** |

`.gitignore` was classified in `/tmp/PR_PARTITION_PLAN.md` §1 as one of four "genuinely
unique deltas (+2/−6)". It is not a delta at all: it is #175's blob verbatim. #185
changed it, removing a `/apps/mobile/` pattern and adding an explanatory comment:

```diff
-# Deprecated duplicate lib trees — canonical source is apps/mobile/lib/
+# Deprecated duplicate lib trees — canonical source is apps/mobile/lib/.
+# Patterns here are anchored to apps/mobile/, so this only guards against a
+# duplicate reappearing *inside* this package. ...
+# Never add `/apps/mobile/` to the root .gitignore — it would untrack this app.
 /voicememory_mobile/
-/apps/mobile/
```

The removed pattern was inert in effect (anchored to `apps/mobile/`, it would only match
`apps/mobile/apps/mobile/`), so restoring it is a documentation/correctness regression
rather than a dangerous one. It is still a revert of deliberate work.

There is arguably a fifth: **197's `tool/gates.yaml` also reverts #188 and #190 inside the
file.** Against #190 it changes `flutter test tool/run_*_self_test.dart` back to
`dart run ...`; against #188 it deletes the `privacy_copy` gate registration that #188
adds. This is why 197's `changed in both` count climbs from 5 at B-tip to 23 at B-final.

### 197 has no durable unique content whatsoever

This is the substantive correction to the prior plan, which recommended extracting four
unique deltas as a small PR. Blob-level comparison of the three supposed deltas:

| path | B-tip (#187) | **#197** | **#198** | #175 |
|---|---|---|---|---|
| `apps/mobile/tool/gates.yaml` | `7f332ee3` | `c08df417` | **`7f332ee3`** | `7f332ee3` |
| `apps/mobile/tool/run_gate.py` | `2064e256` | `3d782282` | **`2064e256`** | `2064e256` |
| `apps/mobile/tool/archive/validate_core.sh` | `6b384a34` | `52bc16df` | **`6b384a34`** | `6b384a34` |
| `apps/mobile/.gitignore` | `a8473454` | `fc344ebf` | `fc344ebf` | `fc344ebf` |

For all three, **#198 restores exactly stack B's blob.** 197 + 198 is a byte-level no-op
against stack B on every one of them. #198 has already been closed on the (correct)
grounds that it is a no-op against stack B — and it is a no-op precisely because 197's
changes that it undoes are also absent from stack B.

The `gates.yaml` +41 lines are a `feature_gates:` block registering 20 gates. **All 20
target test files exist nowhere** — not in 201's 1,154 test files, not in B-tip, not in
today's working tree:

```
test/android_after_ios_proof_gate_test.dart        test/premium_tiers_future_gate_test.dart
test/annual_plan_future_gate_test.dart             test/price_objection_feedback_gate_test.dart
test/archive_memory_after_v1_gate_test.dart        test/private_reports_future_gate_test.dart
test/b2b_workplace_pressure_future_gate_test.dart  test/referral_after_proof_gate_test.dart
test/commercial_readiness_gate_test.dart           test/return_tomorrow_ritual_gate_test.dart
test/contradiction_change_future_gate_test.dart    test/safe_exports_future_gate_test.dart
test/cross_device_continuity_future_gate_test.dart test/safe_sharing_future_gate_test.dart
test/future_expansion_roadmap_gate_test.dart       test/three_day_proof_challenge_gate_test.dart
test/loop_packs_future_gate_test.dart              test/v1_visible_surface_reducer_test.dart
test/payment_proof_not_interest_gate_test.dart     test/post_proof_pro_cta_hardening_test.dart
```

The 23 `tool/archive/run_*.sh` files 197 adds are the shell wrappers for those same
nonexistent tests, and #198's 23 deletions are exactly that set. 197's remaining files:
`.github/workflows/ci.yml`, `.github/workflows/archiveme-stabilization.yml` and
`apps/mobile/.feature_count_budget` are all byte-identical to #175's blobs and therefore
already in stack B.

**Recommendation: close 197 outright. Nothing needs to be re-derived later.** Note this
also means the ordering worry in the prior plan ("198 must be closed with or after 197 is
resolved") is moot in the direction it was stated — 198 was already closed, and because
198 was the thing that neutralised 197's three tool deltas, **197 landing now would be
strictly worse than it would have been before**: the 23 wrapper scripts and the 41 dead
gate registrations would become permanent.

---

## 5. PR 195 — the divergent files, judged against the working tree

The working tree is the right referee here and it is unambiguous about shape: the index
holds **373 mode-`120000` symlinks** under `apps/mobile/lib/features/`, and all seven
contested directories are symlinks into `../../retired_sprawl/lib_features/`. The working
tree agrees with stack B's filesystem shape and disagrees with stack C's.

My independent re-classification of 195's 94 files (93 adds, 1 modify) reproduces the
prior plan's grouping, with one refinement — it is 13 divergent-at-same-path, of which the
prior plan split off 2 as "identical to a stack-B variant":

| group | count |
|---|---|
| identical to B-final at same path | 66 |
| divergent at same path | 13 (= the 11 + 2 stale variants) |
| new at path, identical through the stack-B symlink | 8 |
| new at path, divergent through the stack-B symlink | 4 |
| new at path, identical to a B file at another path | 2 |
| genuinely absent from B-final | 1 |

### Verdicts on the 11

**In not one case does the working tree agree with 195 against stack B.** There is no
"take 195's version" anywhere in this table.

| # | file | 195 | stack B | worktree | verdict |
|---|---|---|---|---|---|
| 1 | `lib/features/onboarding/remote_processing_consent_copy.dart` | `1fdb18b3` | `e5eb4770` | `e5eb4770` | **take stack B** |
| 2 | `lib/router/v1_route_inventory.dart` | `18e8f4a4` | `aa17ea7b` | `64761d5d` | **diverged from both** |
| 3 | `lib/router/v1_route_registry.dart` | `7aebd102` | `db7672e6` | `f4ae6455` | **diverged from both** |
| 4 | `lib/screens/export_screen.dart` | `4ef56cf2` | `d65d43e3` | `d65d43e3` | **take stack B** |
| 5 | `lib/screens/settings_screen.dart` | `28ec5fa6` | `611d4e6d` | `b5a869c8` | **diverged from both** |
| 6 | `lib/security/private_data_service.dart` | `1078ebc9` | `d0e89437` | `17a519f8` | **diverged from both** |
| 7 | `lib/security/release_logger.dart` | `4664995e` | `4855f98e` | `4855f98e` | **take stack B** |
| 8 | `lib/services/app_services.dart` | `f9f7ed4a` | `9b09bc25` | `c0d0df4b` | **diverged from both** |
| 9 | `lib/services/capture_pipeline_service.dart` | `8793b5ae` | `34831802` | `7bc6a446` | **diverged from both** |
| 10 | `lib/services/record_pipeline_log.dart` | `a41e1d38` | `fe0dd031` | `fe0dd031` | **take stack B** |
| 11 | `lib/startup/archive_me_crash_diagnostics.dart` | `6b1999f8` | `46e86f92` | `46e86f92` | **take stack B** |

Five exact matches with stack B; six diverged. The two extra divergent-at-same-path files
the prior plan classified separately resolve the same way:
`test/remote_processing_consent_copy_test.dart` → **take stack B** (worktree `c2ac09ac` =
B-final, from #188) and `test/support/release_suite_static_state_reset.dart` → **take
stack B** (worktree `aa4d73dd` = B-final, from #191).

### What the working tree has that neither PR has

In every diverged case the working tree is a *small* delta from stack B and a *large*
delta from 195 — the direction question the prior plan could not resolve:

| file | 195 → worktree | stack B → worktree | what today added |
|---|---|---|---|
| `v1_route_inventory.dart` | +10/−0 | **+5/−0** | registers `/caregiver-access` as a `v1Supporting` route |
| `v1_route_registry.dart` | +10/−7 | **+2/−0** | adds `caregiverAccessPath = '/caregiver-access'` |
| `settings_screen.dart` | +137/−95 | **+21/−2** | caregiver-access ListTile behind `V1CapabilityRegistry.caregiverMonitoring`; imports `caregiver_grant_entry_point.dart`, `caregiver_access_copy.dart` |
| `private_data_service.dart` | +21/−6 | **+9/−1** | `CaregiverSessionGuard.assertOwnerAccess(exportSanitizedArchive)`; wipe phrase moved to `PrivacyClaimCatalogue` |
| `app_services.dart` | +654/−31 | **+4/−1** | `ProductAnalytics.initialize(consentStore: ProductAnalyticsConsentStore(s.prefs))` |
| `capture_pipeline_service.dart` | +105/−1284 | **+64/−36** | the caregiver export gating — 8 × `await _assertOwnerCapture();` plus the `caregiver_session_guard.dart` import |

`capture_pipeline_service.dart` confirmed exactly as described: 8 occurrences of
`await _assertOwnerCapture();`, one added import, present in neither PR (`grep -c` = 0
against both B-tip's and 195's blobs).

**`app_services.dart` and `capture_pipeline_service.dart` settle the direction question
the prior plan left open.** 195's `capture_pipeline_service.dart` is 1,352 lines; stack
B's is 145 and the working tree's is 173. That is because stack B extracts the pipeline
into **11 modules under `apps/mobile/lib/services/capture_pipeline/`** — which 195's tree
does not contain at all (B-tip: 11 files, 195: 0, working tree: 11). 195's +1300 is the
pre-refactor monolith, not extra work. Same shape on `app_services.dart`: 195 is 1,093
lines against stack B's 1,713 and the working tree's 1,716.

### The four "strictly thinner" files — stack B's extra content is real work

| file | verdict vs worktree | is stack B's extra real? |
|---|---|---|
| `proof_admission/remote_processing_consent_store.dart` | **diverged from both** | **Real.** Stack B adds a `StreamController` and `onChanged` stream, documented as the mechanism by which `BackgroundSyncQueueGateway` reacts to consent instead of polling. A functional API. Today's tree adds a doc comment steering callers to `RemoteProcessingConsentGate.isPurposePermittedNow`. |
| `recording/recording_state_controller.dart` | **take stack B** (worktree = `7bcebd23` exactly) | **Real.** Stack B adds `_recordSurfaceResolutionNotifier`, read by `assembleRecordBuildContext`. |
| `trust/privacy_screen_copy.dart` | **diverged from both** | **Real.** Stack B's extra is #188's corrected privacy copy. 195's version asserts `PrivacyCopyPolicy.journalEncryptedAtRest` and says prefs "remain on this device in plaintext JSON" — the exact claims #188 replaced. Taking 195 would reintroduce inaccurate privacy statements. |
| `voice_capture/audio/audio_diag_log.dart` | **take stack B** (worktree = `43a1d6d1` exactly) | **Real.** Stack B adds three `kReleaseMode`-guarded logging methods (`recordingMessage`, `operationStackTrace`, `micInputHealth`) — which is the very release-logging-safety work 195 exists to do. |

None of the four is a slice-boundary artifact. Two additional tells that 195's copies are
older mechanical snapshots: both `privacy_screen_copy.dart` and `audio_diag_log.dart` in
195 lack a trailing newline where stack B's have one.

One correction to the prior plan's "8 are byte-identical" group:
`voice_capture/transcription/provisional_transcript_reconciler.dart` is byte-identical
between 195 and stack B (`a6910e80`) but the **working tree has moved past both**
(`34b75a33`, +22/−7): today swapped `RemoteProcessingConsentStore` for
`RemoteProcessingConsentGate` and added transcript-provenance handling. So that group is
7 files where both PRs agree with the working tree, not 8.

### Net position for 195

Its only content that is durable *and* not already in stack B is
`apps/mobile/tool/validate_v1_production_graph.sh` — and even that is present in stack B
at `apps/mobile/tool/archive/validate_v1_production_graph.sh`, differing by three deleted
lines. The other two "relocated" files (`tool/validate_mobile_privacy_logs.dart`,
`tool/validate_production_route_links.dart`) are byte-identical to stack B's
`tool/archive/` copies. All three are absent from the working tree entirely.

195 must stay open only for as long as it is #196's base. Once 200/201's content is
re-based off stack B and 196 can be closed, 195 can be closed too, with the single
three-line `validate_v1_production_graph.sh` delta re-derived if wanted.

---

## 6. The 12 files tracked by #186 but untracked in the index

**Confirmed: exactly 12, all present on disk, none gitignored, all showing `??`.**
Of #186's 2,286 `apps/mobile/retired_sprawl/` paths, 2,274 are in the index and 12 are
not. They are exactly the 12 files PR 195 adds under `lib/features/`, seen through the
symlinks.

```
apps/mobile/retired_sprawl/lib_features/activation/archive_insight_feedback.dart
apps/mobile/retired_sprawl/lib_features/billing/application/billing_notifier.dart
apps/mobile/retired_sprawl/lib_features/pattern_naming/pattern_name_store.dart
apps/mobile/retired_sprawl/lib_features/proof_admission/remote_processing_consent_store.dart
apps/mobile/retired_sprawl/lib_features/proof_admission/remote_processing_data_flow.dart
apps/mobile/retired_sprawl/lib_features/proof_admission/remote_processing_purpose.dart
apps/mobile/retired_sprawl/lib_features/recording/recording_state_controller.dart
apps/mobile/retired_sprawl/lib_features/trust/privacy_screen_copy.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/analysis/analysis_log.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/audio/audio_diag_log.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/provisional_transcript_reconciler.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/transcription_log.dart
```

**The prior plan states the footgun backwards.** It says "anyone committing today's work
with `git add -A` will produce a commit that *deletes* these 12 from 186's set unless they
are staged." `git add -A` stages untracked, non-ignored files — I verified with
`git check-ignore -v` that none of the 12 is ignored and with `git status --porcelain
-uall` that all 12 appear as `??`. So **`git add -A` is the operation that fixes this.**

The operations that actually lose them are `git commit` of the index as it stands,
`git commit -a`, and `git add -u` — all three of which touch only tracked paths and would
produce a tree missing 12 of #186's files. That is the rule any subsequent staging must
follow.

Related, and in the opposite direction: `apps/mobile/lib/objectbox.g.dart` and
`apps/mobile/lib/objectbox-model.json` are **in the index but absent from disk**. Here
`git add -A` *is* the dangerous operation — it would stage those deletions. There is no
single `git add` invocation that is correct for both sets; the staging has to be explicit.

---

## 7. Corrected counts for today's work against #186

Measured by hashing every on-disk file with `git hash-object` (no `-w`) and comparing to
#186's blob OIDs, which is index-independent and therefore sees the 12 untracked files
that a `git diff` cannot.

**As of 17:43 local: 31 modified, 6 new, 0 missing.** (2,255 of #186's 2,286 are
byte-identical.) Re-measured at 17:45: still 31.

The prior plan's figure of 25 was correct when taken; the gap is fully explained:

- **3 files its method structurally could not see**, because they are among the 12
  untracked and `git diff` reports them as deleted:
  `proof_admission/remote_processing_consent_store.dart`,
  `trust/privacy_screen_copy.dart`,
  `voice_capture/transcription/provisional_transcript_reconciler.dart`.
- **3 files edited after it ran**, all with mtime 17:36:24–17:36:27:
  `archive_theory/citation_playback_launcher.dart`,
  `comparison_engine/views/comparison_explorer_screen.dart`,
  `relationships/views/consent_management_screen.dart`.

### All 31 modified

```
archive_beliefs/archive_beliefs_presenter.dart
archive_beliefs/belief_change_timeline.dart
archive_theory/citation_playback_launcher.dart                                   [new since prior plan]
capture_flow/adapters/journal_transcript_correction_adapter.dart
capture_flow/adapters/pipeline_capture_adapters.dart
capture_flow/capture_flow_controller.dart
capture_flow/capture_flow_dependencies.dart
capture_flow/capture_flow_phase.dart
capture_flow/interfaces/capture_flow_ports.dart
capture_flow/ui/capture_screen.dart
caregiver/caregiver_copy.dart
caregiver/caregiver_mode_controller.dart
caregiver/caregiver_models.dart
caregiver/caregiver_read_service.dart
comparison_engine/views/comparison_explorer_screen.dart                          [new since prior plan]
consent_audit/consent_audit_service.dart
consent_audit/consent_revocation_store.dart
contradiction_detection/statement_analysis.dart
export/journal_bulk_export_service.dart
privacy/on_device_processing_store.dart
privacy/privacy_security_control_center_copy.dart
privacy/privacy_security_trust_copy.dart
privacy_trust/privacy_trust_copy.dart
proof_admission/remote_processing_consent_store.dart                             [untracked; missed before]
relationships/views/consent_management_screen.dart                               [new since prior plan]
timeline/timeline_entry_display.dart
transcript_correction/transcript_correction_controller.dart
trust/privacy_screen_copy.dart                                                   [untracked; missed before]
trust/trust_reliability_copy.dart
voice_capture/transcription/native_speech_transcription.dart
voice_capture/transcription/provisional_transcript_reconciler.dart               [untracked; missed before]
```

(all under `apps/mobile/retired_sprawl/lib_features/`)

### By directory

| directory | files | named by inventory? | named by partition plan? |
|---|---|---|---|
| `capture_flow` | 7 | no | yes |
| `caregiver` | **4** (inventory said 12) | yes | yes |
| `privacy` | **3** (inventory said 5) | yes | yes |
| `archive_beliefs` | 2 | no | yes |
| `consent_audit` | 2 | no | yes |
| `trust` | **2** (inventory said 2 of 12) | yes | yes (said 1) |
| `voice_capture` | **2** (inventory said 18) | yes | yes (said 1) |
| `archive_theory` | 1 | **no** | **no** |
| `comparison_engine` | 1 | **no** | **no** |
| `contradiction_detection` | 1 | no | yes |
| `export` | 1 | no | yes |
| `privacy_trust` | 1 | no | yes |
| `proof_admission` | 1 | **no** | **no** |
| `relationships` | 1 | **no** | **no** |
| `timeline` | 1 | no | yes |
| `transcript_correction` | 1 | no | yes |

**A note on the framing of the question.** The brief asks to name "the 16 unlisted
directories". The prior plan's "16" is a *file* count, not a directory count — 16 files
spread across 8 directories the inventory did not mention. On today's numbers the
equivalent figure is **20 files across 12 directories** beyond
caregiver/privacy/trust/voice_capture: capture_flow (7), archive_beliefs (2),
consent_audit (2), and one each in archive_theory, comparison_engine,
contradiction_detection, export, privacy_trust, proof_admission, relationships, timeline,
transcript_correction. Four of those twelve — `archive_theory`, `comparison_engine`,
`proof_admission`, `relationships` — are named by **neither** prior document.

### The 6 genuinely new paths (unchanged from the prior plan)

```
apps/mobile/retired_sprawl/lib_features/beta_analytics/product_analytics_consent_store.dart
apps/mobile/retired_sprawl/lib_features/capture_flow/ui/local_transcription_unavailable_card.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/local_transcription_availability.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/local_transcription_choice_store.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/local_transcription_unavailable_copy.dart
apps/mobile/retired_sprawl/lib_features/voice_capture/transcription/transcription_capability_policy.dart
```

**Caveat.** Eleven agents are writing here. `git status --porcelain -uall` went 15,074 →
15,079 entries in five minutes. `HEAD` stayed at `cc346da9` and all remote refs stayed
fixed throughout. Every statement about committed refs is stable; the 31/6 figures are a
17:43–17:45 snapshot.

---

## 8. `pubspec.yaml` / `pubspec.lock`

### The prior plan's diagnosis is correct — verified by blob OID

| ref | `apps/mobile/pubspec.yaml` | `apps/mobile/pubspec.lock` |
|---|---|---|
| `main`, 175, 176, 195, 196 | absent | absent |
| **185, 186, 187 (stack B)** | `2e82bcd2` | `d19bf458` |
| **203, 204 (stack C)** | `2e82bcd2` | `d19bf458` |
| 177 (stack A) | `177ce4f0` | `9552e11e` |
| 179 (stack A) | `961e794f` | `258d99da` |
| 184 (stack A) | `177ce4f0` | `1bce588c` |
| **index** | `2e82bcd2` | `d19bf458` |
| **working tree** | **`4a5e9520`** | `d19bf458` |

Stack B and stack C are byte-identical on both files. The divergence is stack A only.
And #179's conflict is confirmed as exactly this: `git merge-tree` against its own parent
`split/journal-sqlite-core` (merge-base `cbada974`) reports `changed in both` on
`pubspec.lock` (`9552e11e` vs `258d99da`) and on `pubspec.yaml`, with everything else
adding cleanly. It has nothing to do with stack B or C.

### The stale lockfile is real, and worse than reported

Today's manifest edit removes three packages:

```diff
   shimmer: ^3.0.0
-  objectbox: ^5.3.2
-  objectbox_flutter_libs: ^5.3.2
   flutter_gemma: ^1.6.1
...
   mockito: ^5.4.5
-  objectbox_generator: ^5.3.2
```

`apps/mobile/pubspec.lock` is still `d19bf458` — byte-identical to stack B's, untouched —
and still pins all three as `dependency: "direct main"` / `"direct dev"` with sha256
entries at lines 1229, 1237 and 1245 of 280 package entries. The code side of the removal
is complete: **zero** `objectbox` references remain in `apps/mobile/lib` or
`apps/mobile/test`, and `lib/objectbox.g.dart` / `lib/objectbox-model.json` are deleted
from disk (though still in the index — see §6).

**The part neither prior document caught: `apps/mobile/ios/Podfile.lock` has moved in the
opposite direction.** Stack B's copy contains no ObjectBox reference at all. The working
tree's copy is +51 lines over #185's and now *adds* it:

```
  - ObjectBox (5.3.0)
  - objectbox_flutter_libs (0.0.1):
    - ObjectBox (= 5.3.0)
```

So the tree currently holds three mutually inconsistent statements about ObjectBox: the
manifest says removed, `pubspec.lock` says pinned, and `ios/Podfile.lock` says newly
installed. `ios/Pods/` is untracked (0 paths in #185), but `ios/Podfile` and
`ios/Podfile.lock` are both tracked by #185 and both are modified in the working tree.

### What a correct fix requires

1. Take #185's `pubspec.yaml` (`2e82bcd2`) as the base and apply the three removals — the
   working tree's `4a5e9520` already is exactly that.
2. Run `flutter pub get` to regenerate `pubspec.lock`. This is **not** a hand edit: the
   three packages are direct dependencies, and removing them may also drop transitive-only
   entries from the 280-package lock. Deleting the three stanzas by hand would leave any
   orphaned transitives behind and produce a lockfile `pub` would immediately reject.
3. Run `pod install` under `apps/mobile/ios` to regenerate `Podfile.lock`, or the iOS
   build keeps the ObjectBox pod that no Dart dependency requires.

**Both steps are forbidden here and neither was run.** That matters for sequencing: the
manifest change can only be carried by a PR that owns `apps/mobile/pubspec.yaml`, and in
stack B the only such PR is **#185** (`split/mobile-project-scaffold`), which also owns
`pubspec.lock`, `ios/Podfile` and `ios/Podfile.lock` — all four files needed for a
coherent change live in the same PR, which is convenient. But **#185 cannot be updated
correctly by any agent operating under this task's constraints**, because a correct update
requires running `flutter pub get` and `pod install`. Committing the current pair would
land a manifest/lockfile mismatch on stack B, and `flutter-gates` would be the first thing
to notice.

---

## 9. Single highest-risk concern about executing this

**The re-target commands as currently planned would quietly convert seven symlinks into
directories on stack B, and every tool anyone is likely to use to check for that says the
merge is clean.**

Running `gh pr edit 201 --base split/retired-sprawl-tracked` is a one-second, reversible-
looking action. What it produces is a PR whose diff is 2,754 files instead of 1,154, which
re-lands 195 and 196 on top of stack B, and which — if merged — replaces
`apps/mobile/lib/features/{activation,billing,pattern_naming,proof_admission,recording,
trust,voice_capture}` with directories holding one to four files each. The 2,286 files
under `apps/mobile/retired_sprawl/lib_features/` that #186 exists to supply would stop
being reachable at those seven paths, and 5,185 import statements in 201's own test suite
resolve through symlinked feature directories.

The reason this outranks everything else is the detection gap:

- `git merge-tree` in the required three-argument form reports **zero conflicts**.
- GitHub will likely report the PR `MERGEABLE`, since it uses the same merge machinery.
- The 24-of-32 PRs that target a non-`main` base run only the two Vercel checks, which do
  not build Flutter — so no gate would catch it either.
- A symlink replaced by a directory is a legal git change. Nothing warns.

I found this only by enumerating tree entries by mode and testing path-prefix containment
directly. It is not visible in any of the three diff or merge tools the prior analyses
used, which is why both prior documents recorded "0 conflicts" for 201 onto stack B.

Second-order, and unchanged from the prior analysis: I cannot verify that the working-tree
state I measured is the state that gets committed. It moved by 5 status entries during
this analysis, and six of the 31 modified files were touched in the last twenty minutes.

---

## 10. Claims in the two prior documents I checked and found wrong

| # | Claim | Where | Finding |
|---|---|---|---|
| 1 | "201 → stack B, expected conflicts: **none**" and the same for 199, 200, 202, 204. | PARTITION §3 | **Wrong, in the way that matters.** The probe used the PR's own merge-base (`64b8b5d9`), which pre-supposes 195+196 are already applied. Against the real merge-base (`origin/main`) there are **7 file/directory collisions** at every stack-B base for 197, 200, 201 and 204, plus 16 `changed in both` paths at B-final. The old `merge-tree` does not report file/directory conflicts at all. |
| 2 | Implicit throughout §3: that `gh pr edit --base` is the mechanism to preserve 200/201/204. | PARTITION §3, §2 | **Wrong.** `origin/main` is the merge base at all five candidates, so re-targeting changes the diff by nothing. 201 goes from a 1,154-file PR to a 2,754-file PR at *every* candidate base including `main`. Cherry-picking the single commit is the only operation that achieves the stated intent. |
| 3 | "197's genuinely unique deltas: **4** — `tool/gates.yaml`, `tool/run_gate.py`, `tool/archive/validate_core.sh`, `apps/mobile/.gitignore`." | PARTITION §1 | **Wrong on all four.** #198 restores stack B's exact blob for the first three (`7f332ee3`, `2064e256`, `6b384a34`), so 197+198 is a byte-level no-op. `.gitignore` is #175's blob verbatim and reverts #185. **197 has zero durable unique content.** |
| 4 | "197 would revert stack B fixes: **3** files." | PARTITION §1, §9 | **Undercounted.** There are four: the three named, plus `apps/mobile/.gitignore` (reverts #185). Arguably five — 197's `tool/gates.yaml` also reverts #188's `privacy_copy` gate registration and #190's `flutter test` → `dart run` change. |
| 5 | "Recommended split for 197: extract only the four unique deltas as a small PR against stack B." | PARTITION §1, §3 | **Would cause harm.** It would land 41 lines registering 20 gates whose target test files exist in no branch and no working tree, plus 23 shell wrappers for those same nonexistent tests, plus a revert of #185's `.gitignore` cleanup. |
| 6 | "Anyone committing today's work with `git add -A` will produce a commit that *deletes* these 12 from 186's set." | PARTITION §5 | **Backwards.** None of the 12 is gitignored (`git check-ignore -v`: no match) and all show as `??`, so `git add -A` stages them — it is the fix, not the hazard. The hazards are `git commit` of the index as-is, `git commit -a`, and `git add -u`. Separately, `git add -A` *is* hazardous for `lib/objectbox.g.dart` and `lib/objectbox-model.json`, which are in the index but deleted on disk. |
| 7 | "Modifications to files inside PR 186 — exactly **25** files … caregiver 4, privacy 3, trust 1, voice_capture 1, plus 16 in [8 directories]." | PARTITION §5 | **Now 31.** Three were invisible to its `git diff` method because they are among the 12 untracked; three more were edited at 17:36. Current: caregiver 4, privacy 3, trust 2, voice_capture 2, plus 20 files across 12 other directories. Four of those directories (`archive_theory`, `comparison_engine`, `proof_admission`, `relationships`) are named in neither document. |
| 8 | "195's 12 `lib/features/` additions: **8 are byte-identical** to stack B's copy." | PARTITION §1 | **7, not 8.** `voice_capture/transcription/provisional_transcript_reconciler.dart` is identical between 195 and stack B but the working tree has moved past both (`34b75a33`, +22/−7). |
| 9 | On 195's 11 divergent files: "These need a human to read. I am explicitly not confident which side is correct." | PARTITION §1 | **Resolvable, and it resolves one way.** The working tree never sides with 195. Five match stack B byte-for-byte; six are stack B plus today's caregiver work. 195's apparent "extra" on `capture_pipeline_service.dart` (+1300) and `app_services.dart` is pre-refactor monolith: stack B and the working tree both carry 11 extracted modules under `lib/services/capture_pipeline/` that 195's tree lacks entirely. |
| 10 | Implied by "in all four cases 195's version is strictly thinner" without a verdict. | PARTITION §1 | **Thinner is wrong in all four cases.** Stack B's extra content is a consent `Stream` API, a surface-resolution notifier, #188's corrected privacy copy, and three `kReleaseMode`-guarded log methods. Two of the four match the working tree exactly. |
| 11 | "PR 198 has an ordering dependency … 198 must be closed together with or after 197 is resolved." | PARTITION §1 | **Superseded and inverted.** 198 is already closed. Because 198 was what neutralised 197's three tool deltas, 197 landing *now* is strictly worse than before: 23 wrapper scripts and 41 dead gate registrations would become permanent. |
| 12 | "12 of 12 caregiver files, 5 of 5 privacy, 2 of 12 trust, 18 of 32 voice_capture." | INVENTORY §7 | **Confirmed wrong** (as the partition plan said), and the corrected figures are caregiver 4, privacy 3, trust 2, voice_capture 2. |
| 13 | "`pubspec.lock`/`pubspec.yaml` divergent across all three stacks." | INVENTORY §4b | **Confirmed misleading** (as the partition plan said). Stack B and C are byte-identical; divergence is stack A only. Independently re-verified by blob OID at 13 refs. |
| 14 | The partition plan's own stale-lockfile section. | PARTITION §6 | **Correct but incomplete.** It missed that `apps/mobile/ios/Podfile.lock` moved the *other* way — the working tree adds ObjectBox 5.3.0 pods that stack B's copy does not have. A correct fix needs `pod install` as well as `flutter pub get`. |

### Claims I re-verified and found correct

- PR 201 carries 1,149 blobs absent from all of stack B (§3) — exact.
- `delete_branch_on_merge` is `false` (`gh api repos/careos-healthcare/voice-memory`).
- 195's grouping into 66 identical / 13 divergent / 8+4 through-symlink / 2 relocated /
  1 new — reproduced independently.
- 373 symlinks under `apps/mobile/lib/features/` in the index; all seven contested
  directories are symlinks in the working tree.
- #204 = 7,377 files, 100% under `apps/voicememory_mobile/`.
- The `flutter-gates` `working-directory: apps/voicememory_mobile` trap on `main`, and
  #175's rewrite to `apps/mobile`.
- All 19 remote-tracking refs used here are byte-identical to `git ls-remote origin`.

### Not checked

I did not verify the inventory's aggregate overlap counts (2,195 / 1,957 / 238), stack A's
internal conflicts beyond #179's two files, #189's LFS content, PR 120, or any CI log. I
did not attempt the three cherry-picks in §2, because that requires writing objects.

---

## 11. Read-only attestation

**No git write command and no `gh` mutation was run. No file in the repository was
created, modified or deleted.** `HEAD` was `cc346da9f512956dadcb5e4c8dda94bac598a177` at
the start and end.

Git commands used, all read-only: `rev-parse`, `ls-remote`, `merge-base`
(incl. `--is-ancestor`), `ls-tree`, `ls-files`, `cat-file` (`blob`, `--batch`),
`hash-object` (**without `-w`**, and `--stdin-paths` without `-w`, which computes OIDs and
writes nothing), `diff` (`--raw --abbrev=40`, `--name-only`, `--numstat`, `--stat`,
`--no-index`), `log`, `show`, `status --porcelain -uall`, `grep`, `check-ignore`,
`--version`, and `merge-tree` **in its three-argument non-writing form only**.

`gh` usage: `gh pr list --json` and `gh api repos/... --jq` — reads only. No
`gh pr create/edit/close/merge/comment/review/ready` was run.

No `git fetch`. Remote-tracking refs were verified current against `git ls-remote origin`
instead: 19 refs, 0 mismatches.

`apps/mobile/tool/restore_lib_features_symlinks.sh` was **not** executed. No `flutter`,
`dart pub get`, `pod install`, `npm install` or build command was run.

All scratch output is under `/tmp/vrt/`: `pr_states.tsv`, `lsremote.txt`, `trees/*.txt`
(16 refs), `diffs/*.raw` and `*.mergebase` (11 PRs), `mt/*.txt` (20 merge-tree probes),
`blobs/*`, `195_detail.json`, `195_verdicts.json`, `index_files.txt`, `status_t0.txt`,
`198.txt`, `gatetests.txt`, and the analysis scripts `verify201.py`, `collide.py`,
`mergecalc.py`, `matrix.py`. This report is `/tmp/PR_RETARGET_PLAN.md`.
