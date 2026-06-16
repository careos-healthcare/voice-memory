# Archive Intelligence Proof Section

Shows **real** archive value above paywall CTAs — no fabricated counts.

## Copy

**When counts exist:**

```
Your archive has already found:

• {n} recurring themes
• {n} active theories
• {n} changes over time
```

Only lines with **count &gt; 0** are shown (no `0` placeholders).

**Fallback** (no themes, theories, or changes yet):

`Your archive is beginning to identify patterns.`

## Data sources

| Metric | Source |
|--------|--------|
| **Recurring themes** | Distinct `reflection.recurringThemes` labels across `archiveEligibleEvidenceEntries` |
| **Active theories** | `ArchiveV1View.theoryRanking` (primary + secondary), or current `theory` if ranking empty |
| **Changes over time** | `ArchiveChangeFeedView.totalChangeCount` when `hasBaseline && hasChanges` |

Built in `ArchivePaywallStats.fromEntries` → `ArchiveIntelligenceProofView.fromStats`.

Loader (`ArchiveIntelligenceProofLoader`) loads journal + `ArchiveV1Builder` for teasers without preloaded stats.

## Surfaces

| Surface | `paywall_proof_seen.surface` | Component |
|---------|---------------------------|-----------|
| Subscription | `subscription` | `ArchivePaywallBody` above primary CTA |
| Value-moment paywall | `value_moment_blindSpot` / `discover` / `archiveContinuity` | `ArchiveIntelligenceProofLoader` |
| Locked intelligence cards | `archive_intelligence_locked` | `ArchiveIntelligenceUpgradeCard` (monthly / historian / milestone teasers) |

## Analytics

- **Event:** `paywall_proof_seen`
- **Params:** `surface`, `used_fallback` (0/1), optional `theme_count`, `theory_count`, `change_count`

## Screenshots

```bash
cd apps/voicememory_mobile
# Subscription with 5+ eligible recordings and Archive V1 built
./tool/run_ui_screenshot_audit.sh
```

Suggested: `subscription_intelligence_proof.png`, `archive_locked_upgrade_proof.png`

## Tests

```bash
cd apps/voicememory_mobile
flutter test test/archive_intelligence_proof_section_test.dart test/archive_paywall_stats_test.dart
```
