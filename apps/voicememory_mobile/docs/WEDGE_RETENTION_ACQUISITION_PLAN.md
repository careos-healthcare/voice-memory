# ArchiveMe — Wedge, Retention & Acquisition Plan

Revenue-readiness pack — not a new product feature. Defines how ArchiveMe proves wedge strength, repeat usage, low churn, acquisition loop, and willingness-to-pay **before** paid launch.

Branch context on `main`: sticky-loop consolidation, TestFlight QA pack, access protection hardening, milestone cards, review ritual, calendar, Then vs Now, user-confirmed insights.

## Positioning

**One sentence:** ArchiveMe is a private evidence archive for noticing what keeps repeating, what changed, and what to watch next.

**Sharper beta wedge:** For people who keep saying yes when they have no capacity, ArchiveMe helps you save real moments and see the pattern over time.

## Primary wedge

**People who keep saying yes when they have no capacity.**

Pain: agreeing before checking room, then paying the cost later. ArchiveMe turns real moments into cautious evidence — not a verdict.

## Secondary wedge

**People trying to prove they are doing enough.**

Pain: doing more to feel okay, staying busy to avoid feeling behind. ArchiveMe compares moments over time instead of one-off notes.

## Who this is for

- People who notice the same pressure loop showing up again
- People who want a **private** archive of their own words
- People willing to save 3+ real moments and review what repeated
- Early adopters comfortable with TestFlight and honest feedback

## Who this is not for

- Generic daily journaling without a loop to test
- Productivity / task management
- Clinical advice or crisis support
- People who need certainty on day one
- Users who want public sharing of raw entries

## Why this is not generic journaling

ArchiveMe is built around **evidence over time**: save moments → see progress → compare → review weekly → confirm insight → share safe milestone proof. It does not optimize for blank-page writing or mood scores.

## User pain targeted

| Wedge | Pain | ArchiveMe promise |
| --- | --- | --- |
| Capacity yes | Saying yes before checking room | See whether the same yes-pattern repeats |
| Prove enough | Doing more to feel okay | See whether pressure-to-prove keeps showing up |
| Generic fallback | “Something keeps repeating” | Start with cautious compare, not conclusions |

## Onboarding promise

Save real moments privately. After a few saves, ArchiveMe shows cautious evidence of what might repeat, what changed, and what to watch next — without claiming it knows you.

## Acquisition cohorts (in-app)

| Cohort ID | Wedge tested | Start route | Default loop |
| --- | --- | --- | --- |
| `capacity_yes_direct` | Saying yes / no capacity | `/start/capacity-yes` | `capacity_yes` |
| `prove_enough_direct` | Prove enough / doing enough | `/start/prove-enough` | `prove_enough` |
| `generic_archive` | Generic fallback | `/start/prove-enough` | `prove_enough` |
| `unknown` | Unassigned | `/start/prove-enough` | `prove_enough` |

Deep links and invite copy can pass `loop=capacity-yes` or `loop=prove-enough`. See `AcquisitionCohortId` in `lib/features/acquisition/acquisition_cohort_model.dart`.

**Onboarding intent:** `AudienceWedge` maps user choices to loops (`sayingYesNoCapacity` → capacity loop; prove-enough family → prove loop).

**Beta invite pack:** `/beta-invite-pack` — local copy scripts, 3-moment tester task, no uploads.

## Local analytics / milestones (device-only)

| Source | What exists today | External measurement still needed |
| --- | --- | --- |
| `AcquisitionCohort` | Moments 1–3, read accept/reject, loop review, paywall teaser tap | Cohort conversion by channel |
| `RetentionMetricsTracker` | Onboarding, loop events, cohort counters, invite copy events | Day-2/7 return across users |
| `ActivationFunnelAnalytics` | Account, app lock, sticky-loop events | Funnel dashboards |
| Beta feedback / outcomes | Local summaries after 3+ moments | Aggregated WTP survey |
| Pro interest | Local interest signals | Paid conversion (post-RevenueCat) |

## 7-day beta test plan (single tester)

1. **Day 0:** Install TestFlight build; save first typed or voice moment; note onboarding promise.
2. **Day 1:** Save second moment; open Archive Home; confirm sticky loop is calm (not a card wall).
3. **Day 2:** Return to app (day-2 return signal); save third moment if ready.
4. **Day 3:** Open Archive; review what repeated; use insight feedback (fits / not quite).
5. **Day 5:** Open Then vs Now or weekly review if eligible; set review ritual if useful.
6. **Day 7:** Complete beta feedback; answer willingness-to-pay question honestly.
7. **Report:** Did the archive show something useful by moment 3? Would deeper history be worth paying for later?

## 20-user beta plan

| Phase | Target | Success signal |
| --- | --- | --- |
| Recruit | 20 invites sent | 10+ installs |
| Activate | 10+ first saved moment | Understands save flow |
| Core loop | 5+ users with 3 real moments | Archive shows something useful |
| Retain | 3+ day-2 return | Opens app again without push |
| Depth | 3+ weekly review or Then vs Now | Compare path used |
| WTP | 2+ would pay / want deeper history | Honest Pro interest signal |

Recruitment scripts: [BETA_RECRUITMENT_PACK.md](./BETA_RECRUITMENT_PACK.md)

## Acquisition channels (initial)

- Founder DMs (capacity + prove-enough variants)
- LinkedIn / X posts (specific wedge, no hype)
- Private archive / evidence positioning posts
- TestFlight link with cohort query param when testing a wedge
- Support & feedback path for install help

## Activation metrics

See [RETENTION_METRIC_DEFINITIONS.md](./RETENTION_METRIC_DEFINITIONS.md). Minimum bar for beta: first saved moment → third saved moment → first insight viewed → first confirmed or “not quite” feedback.

## Retention metrics

Day-2 return, day-7 return, moments across 3+ days, review ritual set, milestone card copied, export used.

## Willingness-to-pay metrics

Pro preview opened, “would pay” in beta feedback, restore/cross-device ask, deeper history ask, export/backup ask. **No live purchases until RevenueCat and store setup complete.**

## Churn-risk signals

Record once and never return; reject first insight with no second moment; privacy concern; “I don’t know what to say”; opens app but does not record.

## What must be proven before paid launch

- Wedge resonates in user words (not founder words)
- 3-moment task completes for majority of active testers
- Repeat usage without streak pressure
- Insight feedback usable (fits / not quite)
- No privacy blockers in share/calendar/milestone surfaces
- TestFlight physical QA complete ([TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md))
- Sandbox purchase + restore verified **after** RevenueCat configured

## What must not be built yet

- Live RevenueCat checkout
- Server-side entitlement enforcement / anti-sharing
- Forced login before recording
- Mental-health-style scores or clinical framing
- New major surfaces beyond validation docs
- Fake urgency, fake social proof, streak guilt

## Paid launch decision

See [PAID_LAUNCH_DECISION_CHECKLIST.md](./PAID_LAUNCH_DECISION_CHECKLIST.md).

## Related docs

- [BETA_RECRUITMENT_PACK.md](./BETA_RECRUITMENT_PACK.md)
- [RETENTION_METRIC_DEFINITIONS.md](./RETENTION_METRIC_DEFINITIONS.md)
- [TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md)
- [ACCESS_PROTECTION_AUDIT.md](./ACCESS_PROTECTION_AUDIT.md)
- [STICKY_LOOP_PRODUCT_MAP.md](./STICKY_LOOP_PRODUCT_MAP.md)
- [CAPACITY_YES_100K_WEDGE_PLAN.md](./CAPACITY_YES_100K_WEDGE_PLAN.md)
- [CAPACITY_YES_POSITIONING_ONE_PAGER.md](./CAPACITY_YES_POSITIONING_ONE_PAGER.md)
- [CAPACITY_YES_BETA_SCORECARD.md](./CAPACITY_YES_BETA_SCORECARD.md)
