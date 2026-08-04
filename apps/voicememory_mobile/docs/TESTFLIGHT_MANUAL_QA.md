# ArchiveMe — TestFlight Manual QA Pack

Physical-device manual QA script for internal TestFlight before upload and external beta.
Run after #137 sticky-loop consolidation is on `main`.

## Release identity

| Field | Value |
| --- | --- |
| **Public app name** | ArchiveMe |
| **iOS bundle ID** | `com.voicememory.mobile` |
| **Android application ID** | `com.voicememory.mobile` (Play is separate) |
| **Marketing version** | `0.2.0` |
| **Build number** | `49` (`pubspec.yaml` → `version: 0.2.0+49`) |
| **Support URL** | https://careosapp.co.uk/archiveme-support |
| **Primary URL scheme** | `archiveme://` |
| **V1 embedded extensions** | None |
| **V1 explicit entitlements** | None |

## Xcode workspace (required)

Always open:

```
apps/voicememory_mobile/ios/Runner.xcworkspace
```

**Do not open `Runner.xcodeproj`.** CocoaPods integration lives in the workspace only.

## RevenueCat / purchases status

Purchases are **unavailable** until App Store Connect banking and RevenueCat product setup are complete. RevenueCat is paused on this branch — do not claim users can buy Pro. Restore Purchases and Pro Preview must show honest unavailable copy. Do not use purchase CTAs or active-subscription claims in release notes or tester messaging.

## Prerequisites

- **Physical device required** — simulator is not sufficient for mic, TestFlight install, or final sign-off.
- **Fresh install required** — delete prior ArchiveMe build or use a clean TestFlight install before running this script.
- Production API configured for archive upload builds (`VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app`).
- Do **not** pass `ARCHIVEME_TRIAL_MODE=true` or `VOICE_MEMORY_SCREENSHOT_MODE=true` for TestFlight uploads.

---

## Physical-device QA script

Work top to bottom. Mark each step Pass/Fail in the [QA result template](#qa-result-template) below.

### A. Fresh install

1. Install the TestFlight build on a physical iPhone.
2. Launch **ArchiveMe** — confirm home screen label is **ArchiveMe**, not VoiceMemory.
3. Confirm no old VoiceMemory public branding in onboarding, tabs, or Settings.
4. Complete onboarding if shown.
5. On first record attempt, accept or deny microphone — app must remain usable either way.
6. Confirm no purchase prompt blocks core app use (Record / Archive Home reachable).

### B. Capture

1. Save **one typed moment** (Type instead — no mic required).
2. Save **one voice moment** (grant mic on first use if testing voice path).
3. Verify transcript appears and save completes without crash.
4. Verify edit/delete if supported in this build — note if not available.
5. Deny mic on a fresh install (separate device or reset permissions) — confirm typed capture still works and no crash.

### C. Archive Home — sticky-loop priority

Open Archive tab → **Archive Home** (`/archive-belief`).

Verify cards appear in calm priority (not a wall of mature tools):

1. **First Week Path** — visible early; primary CTA continues path / save moment.
2. **Daily Archive Exercise** — one useful action today.
3. **Today's One Question** or Record guidance — on Record if not on Home; no duplicate long prompts on both.
4. **Archive Clarity** — progress stage only; no journal snippets.
5. **Then vs Now** — only when eligible (roughly 5+ moments); cautious compare copy.
6. **Archive Calendar** — counts/rhythm only.
7. **Review Ritual** — local weekly rhythm prefs; no notification permission prompt.
8. **Milestone Cards** — share-safe proof; fixed copy only.

Confirm mature tools (Next evidence, watchlist, depth, etc.) sit under **More archive tools**, not crowding the top.

### D. Sticky loop — open each surface

From Archive Home and Record, open each surface and confirm calm, non-clinical copy:

| Surface | Route hint | Must not contain |
| --- | --- | --- |
| First Week Path | Archive Home card | clinical claims; streak guilt; pressure copy |
| Daily Archive Exercise | Archive Home + Record | pressure / fake urgency |
| Today's One Question | Record | journal/diary framing that crowds capture |
| Archive Clarity | Archive Home | raw entry text |
| Then vs Now | Archive Home → full screen | certainty claims; transcripts |
| Archive Calendar | Archive Home → full screen | entry text or names |
| Review Ritual | Archive Home → setup | notification permission; journal text stored |
| Milestone Cards | Archive Home → share screen | private journal text in share copy |

Language should prefer: **saved moment**, **archive**, **evidence**, **compare**, **what repeated**, **what changed**, **what to watch next**, **one useful moment is enough**.

### E. Beta / reviewer routes

1. **Sample Archive** (`/sample-archive`) — example data only; does not write to real journal.
2. **Help & reviewer guide** (`/help-reviewer-guide`).
3. **Support & feedback** (`/support-feedback`) — support URL opens externally.
4. **Beta Feedback** — local feedback only (after 3+ real moments if gated).
5. **Beta Outcomes** — summary only; no private text.
6. **Pro Preview** (`/pro-preview`) — future value only; no working purchase.
7. **Restore Purchases** — honest purchases-unavailable copy until RevenueCat is configured.

### F. Privacy

1. Sample archive / demo entries (`sample_archive_*`) do **not** count toward real progress.
2. Share cards and milestone share text contain **no journal text** — fixed safe copy + counts only.
3. Calendar shows **counts only** — no entry previews.
4. Insight feedback (thumbs) stores **no raw text**.
5. Review ritual stores **no raw text** — local rhythm metadata only.
6. Settings → Privacy & data controls — clear local data works.
7. After clearing data, progress resets (Archive Home returns to early-user state).

### G. Export / share

1. Open export pack if available (Settings → Privacy & data).
2. Export contains user-owned archive data only — review before sharing externally.
3. Share-safe proof uses fixed safe copy — no raw private text in public/share surfaces.

### H. Deep links

Test on device if feasible; otherwise mark **manual later**:

- `archiveme://` — primary scheme (widget / deep link target).
- Focused V1 Release intentionally omits legacy and extension-only URL routes.

### I. Offline

1. Enable airplane mode.
2. Launch ArchiveMe — app opens without blocking network error.
3. Save typed moment if supported offline — note behavior.
4. Open archive locally — entries visible from local store.

### J. Build / App Store readiness

1. No placeholder app icon warning in release build log.
2. Launch screen looks correct on device (not default Flutter placeholder).
3. TestFlight build number matches `pubspec.yaml` build `49` (or a later
   value first recorded in `pubspec.yaml`).
4. Support URL https://careosapp.co.uk/archiveme-support loads in Safari.
5. In-app Privacy (`/privacy`) and Terms (`/terms`) routes open.

### K. Accessibility — physical iPhone required

Run this section on a real iPhone so safe-area insets, VoiceOver focus, and
hardware accessibility settings match TestFlight behavior.

1. Turn on VoiceOver. Traverse Future Preview, Life Evidence graph, semantic
   Archive search, and conclusion cards using swipe navigation. Confirm headers,
   selected stage/filter state, result summaries, confidence/uncertainty, and
   actionable evidence are announced once.
2. In the graph, use the accessibility actions rotor to center/reset the canvas
   and switch to Entity list. Open an entity, dismiss its detail sheet, and
   confirm focus returns to the graph/list control that launched it.
3. In semantic search, activate an example, wait for the live result-count
   announcement, open a result, and use “Repeat match explanation”. Confirm
   date, mood when present, reason, and snippet are included.
4. In Future Preview, confirm VoiceOver-style accessible navigation disables
   horizontal page swipes while stage chips and Previous/Next buttons continue
   to work. Open and dismiss graph/evidence/history sheets; each sheet must
   focus its heading and restore focus on close.
5. Settings → Accessibility → Display & Text Size → Larger Text: test every
   Accessibility size through the maximum AX size (approximately 200–320%).
   Repeat in portrait and short landscape. Content must scroll without clipped
   headings, hidden evidence, or an action bar that starves the stage content.
6. Turn on Reduce Motion. Center/reset the graph and move between preview
   stages. Transitions must complete immediately without zoom/page animation.
7. Test increased contrast if available. Search highlights, selected filters,
   focus indicators, and disabled controls must remain distinguishable without
   relying on color alone.
8. Check a notched/Dynamic Island iPhone in portrait and landscape. Bottom
   sheets, close controls, and action bars must remain inside the real safe area.
9. Confirm every icon/chip/button target is at least 44×44 pt (48×48 pt for
   primary controls) and keyboard/Switch Control traversal follows visual order.

### L. Screenshot-mode checks (optional build)

Only if validating a screenshot-mode build separately — **not** for TestFlight upload:

- Live-user-specific sticky-loop cards hidden on Archive Home.
- Sample/demo states use static safe copy only.

---

## QA result template

Copy this table per tester / build. Attach screenshots for blockers and major issues.

| Area | Pass/Fail | Device | iOS version | Notes | Screenshot needed |
| --- | --- | --- | --- | --- | --- |
| Fresh install | | | | | |
| App name ArchiveMe | | | | | |
| No VoiceMemory branding | | | | | |
| Onboarding | | | | | |
| Mic accept path | | | | | |
| Mic deny path | | | | | |
| No purchase block | | | | | |
| Typed moment save | | | | | |
| Voice moment save | | | | | |
| Transcript / save flow | | | | | |
| Edit / delete (if supported) | | | | | |
| Archive Home priority | | | | | |
| First Week Path | | | | | |
| Daily Archive Exercise | | | | | |
| Today's One Question | | | | | |
| Archive Clarity | | | | | |
| Then vs Now (when eligible) | | | | | |
| Archive Calendar | | | | | |
| Review Ritual | | | | | |
| Milestone Cards | | | | | |
| No card wall | | | | | |
| Calm non-clinical copy | | | | | |
| Sample Archive | | | | | |
| Help & reviewer guide | | | | | |
| Support & feedback | | | | | |
| Beta Feedback | | | | | |
| Beta Outcomes | | | | | |
| Pro Preview | | | | | |
| Restore Purchases | | | | | |
| Purchases unavailable copy | | | | | |
| Sample data excluded from progress | | | | | |
| Share / milestone privacy | | | | | |
| Calendar counts only | | | | | |
| Insight feedback no raw text | | | | | |
| Review ritual no raw text | | | | | |
| Privacy controls / clear data | | | | | |
| Export / share safety | | | | | |
| Deep links | | | | | |
| Offline launch | | | | | |
| Launch screen / icon | | | | | |
| Support URL | | | | | |
| Privacy / terms routes | | | | | |
| VoiceOver reading and actions | | | | | |
| VoiceOver focus restoration | | | | | |
| Dynamic Type 200–320% | | | | | |
| Reduce Motion | | | | | |
| Real iPhone safe areas | | | | | |
| 44/48 pt controls and focus order | | | | | |

### Severity labels

- **Blocker** — crash, data loss, private text leaked, purchase misrepresentation, cannot save moments.
- **Major issue** — sticky loop broken, Archive Home card wall, mic deny crash, support URL broken.
- **Minor issue** — copy inconsistency, layout glitch, non-blocking route delay.

### Release readiness summary

| Status | Criteria |
| --- | --- |
| **Ready for TestFlight upload** | Focused tests pass; iOS release build passes; no placeholder icon warning; identity docs match pubspec. |
| **Ready for external beta** | At least 2 internal devices pass full script; no crash on fresh install; 3-moment task completable; privacy/share checks pass; support path works. |
| **Not ready** | Any blocker open; private data in share/calendar/milestone surfaces; dishonest purchase copy; Archive Home unusable. |

---

## Release decision checklist

### Internal TestFlight ready when

- [ ] Focused automated tests pass (see [Related docs](#related-docs)).
- [ ] `flutter build ios --release --no-codesign` passes with no placeholder icon/launch warnings.
- [ ] Physical device fresh install passes sections A–B.
- [ ] Typed capture passes.
- [ ] Voice capture passes (or mic-deny path documented as pass).
- [ ] Archive Home sticky loop passes section C–D.
- [ ] Privacy controls pass section F.
- [ ] Purchase-unavailable copy passes on Pro Preview and Restore Purchases.
- [ ] Support & reviewer routes pass section E.

### External TestFlight ready when

- [ ] At least **2 internal devices** complete this script with no blockers.
- [ ] No crash on fresh install.
- [ ] No private data appears in sample/share/calendar/milestone surfaces.
- [ ] User can complete **3-moment task** (three real saved moments, progress visible).
- [ ] Support URL and feedback path work.
- [ ] App Store reviewer notes are current (`docs/APP_REVIEW_NOTES.md`, `APP_STORE_SUBMISSION_PACK.md`).

---

## Related docs

- [STICKY_LOOP_PRODUCT_MAP.md](./STICKY_LOOP_PRODUCT_MAP.md) — feature roles and priority (#137)
- [TESTFLIGHT_BUILD_NOTES.md](./TESTFLIGHT_BUILD_NOTES.md) — build commands and upload steps
- [IOS_RELEASE_CHECKLIST.md](./IOS_RELEASE_CHECKLIST.md) — iOS release checklist
- [../APP_STORE_SUBMISSION_PACK.md](../APP_STORE_SUBMISSION_PACK.md) — submission one-pager
- [../README.md](../README.md) — project overview

## Automated doc validation

```bash
cd apps/voicememory_mobile
flutter test test/testflight_manual_qa_pack_test.dart
```
