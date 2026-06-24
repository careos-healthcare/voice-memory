# ArchiveMe — Retention Metric Definitions

Local and external metrics for beta validation. Counts in `RetentionMetricsTracker` and `AcquisitionCohort` are **device-local** unless exported manually — plan external aggregation for 20-user beta.

## Activation

| Metric | Definition | Local signal |
| --- | --- | --- |
| First saved moment | User completes first real journal save | `cohortFirstMomentRecorded`, journal count ≥ 1 |
| Second saved moment | Second distinct save | `secondMomentRecorded`, `cohortSecondMomentRecorded` |
| Third saved moment | Third distinct save — beta core task | `thirdMomentRecorded`, `cohortThirdMomentRecorded` |
| First archive insight viewed | User sees first cautious read / insight card | Loop read cards, archive home clarity |
| First confirmed insight | User marks insight as fitting | `readUsefulTapped`, `firstReadAccepted` |
| First Then vs Now card | Eligible compare surface shown/opened | Then vs Now gates, archive home |
| First weekly review opened | Weekly archive review screen opened | Weekly review route |
| First review ritual set | Local weekly rhythm prefs saved | Review ritual store |
| First milestone card copied/shared | Share-safe milestone proof copied | Milestone share store / copy events |

## Retention

| Metric | Definition | Local signal |
| --- | --- | --- |
| Day-2 return | App opened on calendar day 2 after first save | Session / last-open vs first-save date |
| Day-7 return | App opened on day 7 after first save | Same |
| Week-2 return | App opened 8–14 days after first save | Same |
| Moments across 3+ days | Saves on ≥3 distinct calendar days | Journal entry dates |
| Review ritual used | User opens weekly review from ritual path | Review ritual + weekly review |
| User confirms insight fits | “Useful” / fits feedback | `readUsefulTapped` |
| User says not quite and continues | “Not quite” but saves again | `readNotQuiteTapped` + moment 2+ |
| Export / share / milestone use | User exports or copies share-safe proof | Export route, milestone share |

## Willingness to pay (pre-RevenueCat)

| Metric | Definition | Local signal |
| --- | --- | --- |
| Pro preview opened | User views `/pro-preview` | Navigation / analytics |
| Says “would pay” | Beta feedback or Pro interest positive | Beta feedback, Pro interest store |
| Asks for restore / cross-device | Account or restore path used | Account auth, restore taps |
| Wants deeper history | Feedback mentions long-term / deeper evidence | Beta feedback text (manual review) |
| Wants export / backup | Export pack opened | Export route |
| Paywall teaser tapped | Loop paywall teaser (no purchase) | `loopPaywallTeaserTapped`, `cohortPaywallTeaserTapped` |

**Note:** Purchases are unavailable until RevenueCat and App Store setup complete. WTP signals are qualitative until sandbox billing is verified.

## Churn risk

| Signal | Definition | Response |
| --- | --- | --- |
| Record once, never return | One save, no day-2 open | Follow-up DM; check onboarding friction |
| Rejects first insight | `firstReadRejected` without second save | Improve prompt / wedge match |
| No second moment | Stuck after moment 1 | Today's One Question / daily exercise |
| No third moment | Beta task incomplete | Day-3 follow-up |
| Opens app, no record | Session without save | Record prompt clarity |
| “Don't know what to say” | Support / feedback theme | First Week Path, one question |
| Privacy concern | Feedback or support | Sample archive, privacy controls |
| Does not understand archive value | Beta outcomes “not useful” | Wedge mismatch; try other cohort |

## Beta success (minimum)

From Beta Invite Pack:

**Save 3 real moments → return once → review what repeated → tell us if it fits.**

## Cohort comparison

| Cohort | Primary metric | Secondary metric |
| --- | --- | --- |
| `capacity_yes_direct` | Moment 3 + loop review confirmed | Day-2 return |
| `prove_enough_direct` | Moment 3 + read accepted or not quite + continue | Pro preview open |
| `generic_archive` | Moment 3 + archive home engagement | WTP maybe/yes |

## Related docs

- [WEDGE_RETENTION_ACQUISITION_PLAN.md](./WEDGE_RETENTION_ACQUISITION_PLAN.md)
- [PAID_LAUNCH_DECISION_CHECKLIST.md](./PAID_LAUNCH_DECISION_CHECKLIST.md)
