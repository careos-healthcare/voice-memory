# Core Metrics Beta Reducer v1

Reduce beta decisions to a **tiny core metric set** while keeping all existing analytics intact.

## Goal

Beta decisions must use core metrics only. Everything else stays diagnostic and not release-blocking.

## Core metrics (13)

| Metric | Bucket |
| --- | --- |
| `appOpened` | decisionMetric |
| `firstSave` | decisionMetric |
| `secondSave` | decisionMetric |
| `firstUsefulProofSeen` | decisionMetric |
| `proofAccepted` | decisionMetric |
| `proofCorrected` | decisionMetric |
| `proPromiseSeen` | decisionMetric |
| `proTapped` | decisionMetric |
| `purchaseStarted` | revenueMetric |
| `purchaseCompleted` | revenueMetric |
| `restoreSucceeded` | decisionMetric |
| `entitlementActive` | decisionMetric |
| `crashOrBlocker` | releaseBlocking |

## Everything else

- `diagnosticOnly`
- `notDecisionMetric`
- `notReleaseBlocking`

Examples: activation loop counters like `recordScreenSeen`, `thirdMomentSaved`, and funnel events like `thread_return_evidence_seen`.

## Key rules

- **Do not delete analytics**
- **Do not stop existing analytics**
- **Classify only**
- Beta decisions must use **core metrics only**

## Reduction notes

- Delegates event aliases to `CoreMetricsMinimumSet.classify()`
- `restoreTapped` from the minimum set is **not** a beta decision metric
- Purchase metrics are core but bucketed as `revenueMetric`
- Crash/blocker is core but bucketed as `releaseBlocking`

## Code modules

- Engine: `lib/features/core_metrics_minimum/core_metrics_beta_reducer.dart`
- Copy: `lib/features/core_metrics_minimum/core_metrics_beta_reducer_copy.dart`
- Tests: `test/core_metrics_beta_reducer_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/core_metrics_beta_reducer_test.dart
```
