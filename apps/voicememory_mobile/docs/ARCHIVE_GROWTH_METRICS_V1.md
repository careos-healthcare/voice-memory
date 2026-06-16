# Archive Growth Metrics V1

Replaces streak- and day-journey-centric framing on archive home, account, and paywall with three trust-oriented metrics.

## UI

`ArchiveGrowthCard` shows a single row:

| Label | Example value |
|-------|----------------|
| Archive Confidence | `34%` |
| Evidence | `18 recordings` |
| Maturity | `Growing` |

Optional one-line explanation below (archive home and account; hidden on compact paywall surfaces).

## Metric definitions

### Archive Confidence

- **Source:** `ArchiveConfidenceEngine` (`lib/features/archive_growth/archive_confidence_engine.dart`)
- **Range:** 0–100%, displayed as an integer percent.
- **Meaning:** How much signal the archive has to name and track patterns — not a gamified score or login streak.
- **Inputs (weighted):**
  - Eligible recording count (up to ~40 points, scales toward 50 recordings)
  - Current theory confidence from Archive V1 (up to ~30 points)
  - Theory evidence count (up to ~20 points)
  - Active contradictions when present (up to ~10 points)
- **Copy:** Short explanation string chosen from recording count, theory confidence, and overall score (e.g. “still gathering evidence”, “building a clearer picture”).

### Archive Evidence

- **Source:** `ArchiveGrowthMaturity.recordingCount`, which uses the same eligible entries as the confidence engine via `archiveEligibleEvidenceEntries`.
- **Display:** `N recordings` (or `1 recording`).
- **Meaning:** Count of reflections with usable transcript length and content that count as archive evidence — not total app opens or calendar days.

### Archive Maturity

- **Source:** `ArchiveGrowthMaturity.fromRecordingCount` (`lib/features/archive_growth/archive_growth_maturity.dart`)
- **Labels:** Seed → Growing (10+) → Established (50+) → Insightful (100+) → Historian (200+)
- **Meaning:** Qualitative stage of how much history the archive can learn from; replaces “X until next level” and Day 1/3/7 journey banners on the archive home.

## Surfaces

| Surface | Widget | Notes |
|---------|--------|--------|
| Archive home | `ArchiveGrowthCard` on `ArchiveBeliefScreen` | Journey banner removed from home |
| Account | `ArchiveGrowthCard` on `AccountScreen` | Shown when evidence count &gt; 0 |
| Paywall | `ArchiveGrowthCard` on `MobileSubscriptionScreen`; `ArchiveGrowthCardLoader` on `ValueMomentPaywallCard` | Compact, no explanation line |

## Screenshots

Capture after seeding a device or simulator with 10+ eligible recordings:

```bash
cd apps/voicememory_mobile
# Archive tab, Account (/account), subscription (/subscription), value-moment paywall (Discover/Blind spot)
./tool/run_ui_screenshot_audit.sh
```

Suggested filenames under `~/Desktop/upload12/screenshots/`:

- `archive_home_growth_metrics.png`
- `account_growth_metrics.png`
- `subscription_growth_metrics.png`

## Tests

```bash
cd apps/voicememory_mobile
flutter test test/archive_growth_metrics_test.dart test/archive_growth_test.dart
```
