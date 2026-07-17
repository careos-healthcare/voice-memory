# Post-Beta Response Roadmap

Evidence-based decision framework for what to build **after** the first TestFlight cohort — not all at once.

## Purpose

Beta feedback will point to different root causes. This roadmap maps each signal to **one scoped branch**, one success metric, and explicit forbidden work. Do not build all branches in parallel.

## Canonical positioning (unchanged)

| Layer | Copy |
| --- | --- |
| Umbrella | A private mind map of what keeps repeating in your life. |
| Product promise | Save real moments. ArchiveMe connects them into patterns, changes, and next things to watch. |
| First guided path | Start with one pattern — saying yes when you have no capacity. |
| Capacity wedge | Catch the yes before it costs you. |

## Global rules

- **One branch per dominant failure signal** — wait for repeated evidence before opening a second branch.
- **Do not build all branches at once.**
- **Do not add new dashboards** to address these post-beta fixes.
- **Do not enable RevenueCat** before **2–3 clear paid-intent users** plus sandbox purchase/restore proof.
- **No payments, subscriptions, backend, notifications, second guided path, or dependency upgrades** until the matching branch is explicitly chosen by evidence.
- Copy guardrails apply to every branch: no therapy / diagnosis / medical / treatment language; no mental health score, wellbeing score, clinical score, or life score; avoid explicit personalization anchors; no fake stats or testimonials; do not claim everything stays on device; do not overclaim encryption; do not expose private transcript text.

## Branch decision matrix

| # | If testers report… | Branch | Success metric |
| --- | --- | --- | --- |
| 1 | Users do not understand the app | `onboarding-clarity-post-beta` | ≥70% can explain the app after first screen |
| 2 | Users save once but not 3 moments | `activation-simplification-post-beta` | ≥50% of first-save users reach 3 moments |
| 3 | Daily change feels obvious | `daily-change-rules-post-beta` | ≥50% mark daily change useful or return after seeing it |
| 4 | Alternatives feel weak | `fixed-alternatives-post-beta` | ≥50% say the alternative is usable |
| 5 | Quick capture still feels like work | `one-tap-capture-post-beta` | ≥70% say quick capture is quick enough / mostly quick enough |
| 6 | Users return and 2–3 would pay | `revenuecat-readiness-post-beta` | 2–3 clear paid-intent users + sandbox purchase/restore proof |
| 7 | Users like it but forget to return | `local-review-ritual-post-beta` | Return rate improves without pressure reports |
| 8 | Users want broader patterns | `second-guided-path-post-beta` | Capacity path shows retention first; ≥5 testers ask for broader patterns |
| 9 | Users worry about privacy | `metadata-privacy-hardening-post-beta` | Privacy concern no longer blocks beta usage |
| 10 | TestFlight reviewers struggle | `app-review-path-polish-post-beta` | Reviewer completes path without help |

---

## 1. Users do not understand

**Branch:** `onboarding-clarity-post-beta`

**Scope:** Onboarding copy only.

**Allowed**

- Headline / body copy
- How-it-works dialog
- First path explanation
- App Store copy alignment

**Forbidden**

- New product features
- New dashboards
- Paid changes
- Backend changes

**Success metric:** At least **70%** of testers can explain the app after the first screen.

**Current status:** Addressed in beta by [BETA_FOUR_FAILURE_RESPONSE_RULES.md](./BETA_FOUR_FAILURE_RESPONSE_RULES.md) (onboarding fallback). Re-open this branch only if post-TestFlight interviews still show confusion.

---

## 2. Users save once but not 3

**Branch:** `activation-simplification-post-beta`

**Scope:** Activation flow only.

**Allowed**

- 1/3 and 2/3 card copy
- Card priority
- Return trigger copy
- Quick capture CTA placement

**Forbidden**

- New guided paths
- Paid changes
- Dashboards
- Notifications

**Success metric:** At least **50%** of first-save users reach 3 moments.

**Current status:** Addressed in beta by activation fallback (Done for now primary, event-driven 1/3–2/3). Re-open only if cohort data shows <50% reaching 3 moments.

---

## 3. Daily change feels obvious

**Branch:** `daily-change-rules-post-beta`

**Scope:** Daily change rules only.

**Allowed**

- Response categories
- Signal combination rules
- Specific “what changed” copy

**Forbidden**

- New storage unless necessary
- Broad intelligent generation
- Private transcript exposure
- New screens

**Success metric:** At least **50%** of users who see daily change mark it useful or return after seeing it.

**Current status:** Six sharper categories shipped in beta four failure pack. Tune rules in this branch only if usefulness stays low.

---

## 4. Alternatives feel weak

**Branch:** `fixed-alternatives-post-beta`

**Scope:** Fixed alternatives only.

**Allowed**

- Pull-specific labels
- Fixed text templates
- Selected boundary response priority

**Forbidden**

- Generated free text
- Coaching-style language
- New dashboards

**Success metric:** At least **50%** of users say the alternative is usable.

**Current status:** Pull-specific fixed mappings shipped in beta. Extend templates here — do not add generation.

---

## 5. Quick capture still feels like work

**Branch:** `one-tap-capture-post-beta`

**Scope:** Reduce quick capture to fewer taps.

**Allowed**

- One-tap “save pull” mode
- Default timing selection
- Skip optional decision by default
- Fixed local IDs only

**Forbidden**

- Free text
- Private notes
- Backend
- New analytics payloads

**Success metric:** At least **70%** say quick capture is quick enough or mostly quick enough.

**Current status:** Not built — open when friction check / interview data shows “still work” after copy-only fixes.

---

## 6. Users return and 2–3 would pay

**Branch:** `revenuecat-readiness-post-beta`

**Scope:** RevenueCat readiness only after proof.

**Allowed**

- RevenueCat product IDs
- Sandbox purchase
- Restore purchase
- Entitlement persistence
- App Store product checklist
- Paid beta copy

**Forbidden**

- Paid launch from one maybe-paid user
- Fake urgency
- “Buy now”
- “Subscribe now”
- “Pro is active” unless actually entitled

**Success metric:** **2–3 clear paid-intent users** plus sandbox purchase/restore proof.

**Gate:** Do not enable RevenueCat before this evidence. See [PAID_LAUNCH_DECISION_CHECKLIST.md](../apps/voicememory_mobile/docs/PAID_LAUNCH_DECISION_CHECKLIST.md).

---

## 7. Users like it but forget to return

**Branch:** `local-review-ritual-post-beta`

**Scope:** Local reminder / review ritual only.

**Allowed**

- Opt-in local reminder
- Review ritual schedule
- No guilt / streak language
- No push notification backend

**Forbidden**

- Notification pressure
- Streaks
- Daily guilt
- Server push

**Success metric:** Return rate improves without users reporting pressure.

**Current status:** Not built — open when retention interviews cite “forgot” not “didn’t understand.”

---

## 8. Users want broader patterns

**Branch:** `second-guided-path-post-beta`

**Scope:** Add **one** second guided path only.

**Recommended second path:** Thoughts that keep looping.

**Possible copy:** Start another pattern: thoughts that keep looping.

**Allowed**

- One new guided path
- Fixed copy
- Reuse existing capture / pattern engine

**Forbidden**

- Many categories at once
- Clinical or health-service framing

**Success metric:** Capacity path shows retention first, and at least **5 testers** ask for broader patterns.

**Gate:** Do not add until capacity wedge retention is proven.

---

## 9. Users worry about privacy

**Branch:** `metadata-privacy-hardening-post-beta`

**Scope:** Encrypt more metadata / reduce network dependency.

**Allowed**

- Encrypt selected prefs / feature metadata
- Reduce plaintext caches
- Improve temp audio cleanup
- Clearer privacy copy
- Local-only mode clarity

**Forbidden**

- Overclaiming
- “Everything stays on device”
- “Fully encrypted archive” unless true

**Success metric:** Privacy concern no longer blocks beta usage.

---

## 10. TestFlight reviewers struggle

**Branch:** `app-review-path-polish-post-beta`

**Scope:** Reviewer path only.

**Allowed**

- Reviewer notes
- Sample archive route polish
- App review support path
- Clear disabled-purchases copy
- First-run clarity

**Forbidden**

- New features
- Paid launch
- Hidden review-only behavior that misrepresents the app

**Success metric:** Reviewer can complete path without help.

---

## What this roadmap deliberately does not build now

- Broad product surfaces or another dashboard
- RevenueCat, payments, or subscriptions (until branch 6 gate)
- Backend work or server push notifications
- Second guided path (until branch 8 gate)
- Dependency upgrades (see [DEPENDENCY_MAINTENANCE_PLAN.md](../apps/voicememory_mobile/docs/DEPENDENCY_MAINTENANCE_PLAN.md))
- App Store upload or bundle / name changes

## Related docs

- [BETA_FOUR_FAILURE_RESPONSE_RULES.md](./BETA_FOUR_FAILURE_RESPONSE_RULES.md) — in-beta fallbacks for branches 1–4
- [TESTFLIGHT_BETA_LAUNCH_PLAN.md](../apps/voicememory_mobile/docs/TESTFLIGHT_BETA_LAUNCH_PLAN.md) — cohort targets and observation plan
- [PAID_LAUNCH_DECISION_CHECKLIST.md](../apps/voicememory_mobile/docs/PAID_LAUNCH_DECISION_CHECKLIST.md) — paid and RevenueCat gates
- [DEPENDENCY_MAINTENANCE_PLAN.md](../apps/voicememory_mobile/docs/DEPENDENCY_MAINTENANCE_PLAN.md) — upgrade timing after beta
