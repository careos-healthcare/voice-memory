# Core metrics minimum set v2

Classify release-beta metrics vs diagnostic funnel noise, wire a developer-only dashboard, and enforce the classifier in CI.

## v2 additions

- **Developer dashboard** — `CoreMetricsMinimumSetCard` on Internal diagnostics (`/developer-diagnostics`)
- **TestFlight bridge** — `CoreMetricsMinimumSetV2.classifyTestFlightDashboard()` tags dashboard rows core vs diagnostic
- **CI bundle** — `tool/run_core_metrics_minimum_set.sh`

## Core beta metrics (14)

Same as v1: app opened through crash/blocker reported.

## Run CI bundle

```bash
cd apps/mobile
bash tool/run_core_metrics_minimum_set.sh
```

Included in `tool/validate_core.sh`.

## Code modules

- Classifier v1: `lib/features/core_metrics_minimum/core_metrics_minimum_set.dart`
- Dashboard + CI v2: `lib/features/core_metrics_minimum/core_metrics_minimum_set_v2.dart`
- Developer card: `lib/widgets/debug/core_metrics_minimum_set_card.dart`

## Rules

- Do not delete analytics.
- Do not change analytics emission unless clearly wrong.
- No new beta-facing product surfaces (developer diagnostics only).
