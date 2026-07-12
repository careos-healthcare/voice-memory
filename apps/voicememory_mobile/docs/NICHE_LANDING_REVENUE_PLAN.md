# Niche landing revenue plan v1

Define **revenue-focused acquisition pages** without adding app UI. Marketing and web classification only.

## Decisions

| Decision | Meaning |
| --- | --- |
| `landingPlanFrozen` | Landing plan blocked until guardrails pass |
| `landingPlanDocumented` | Six niche pages documented with shared promises (default) |

## Landing pages (6)

1. `sayingYesNoCapacity` — Saying yes/no capacity
2. `proveEnough` — Prove enough
3. `relationshipReplay` — Relationship replay
4. `repeatingHabit` — Repeating habit
5. `workPressure` — Work pressure
6. `overcommitment` — Overcommitment

## Canonical promises

- **Core promise:** "Save one repeat. ArchiveMe compares it later."
- **Paid promise:** "Pro keeps the longer proof trail."

## Rules (4)

1. Marketing/web, not app V1 feature surface
2. No medical or wellness-treatment claims
3. Core promise on every landing page
4. Paid promise documented

## Scope

**Marketing/web only** — niche landing pages are acquisition surfaces, not app V1 feature surfaces.

**Always blocked:**

- Medical or wellness-treatment claims
- In-app V1 landing screens
- Per-page promise drift away from canonical core/paid copy

## Guard helpers

`NicheLandingRevenuePlan.landingPagePassesRules()` and `evaluateCopyPassesRules()` enforce copy guardrails.

## CI bundle

`tool/run_niche_landing_revenue_plan.sh` runs:

- `test/niche_landing_revenue_plan_test.dart`

## Code modules

- Engine: `lib/features/niche_landing_revenue/niche_landing_revenue_plan.dart`
- Copy: `lib/features/niche_landing_revenue/niche_landing_revenue_copy.dart`
- Tests: `test/niche_landing_revenue_plan_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/niche_landing_revenue_plan_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_niche_landing_revenue_plan.sh
```
