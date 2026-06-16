# Archive Discovery Share Cards V2

In-context **Share Discovery** on archive insight surfaces. Premium PNG cards with light/dark palettes, evidence counts, and system share sheet (iOS + Android). No new AI — reuses deterministic archive + cached monthly synthesis.

## Card layout

| Field | Copy |
|-------|------|
| Headline | `My archive noticed:` |
| Main insight | `{insight}` — plain text from existing engines |
| Supporting evidence | `Based on {N} recording(s)` |
| Footer | `ArchiveMe` |

Export size: **360×420** logical at **3×** pixel ratio (`archive_discovery_share_copy.dart`).

## In-context surfaces

| Moment | Surface key | Widget |
|--------|-------------|--------|
| Theory change (then/now) | `archive_theory_change` | `ArchiveBeliefEvolutionThenNow` |
| Belief weakened (change feed) | `archive_change_feed_belief` | `ArchiveChangeFeedSection` |
| Major contradiction (V1) | `archive_contradiction` | `ArchiveV1ContradictionsSection` |
| Change-feed contradiction | `archive_change_feed_contradiction` | `ArchiveChangeFeedSection` |
| Belief lifecycle event | `archive_belief_lifecycle` | `BeliefLifecycleSection` |
| Monthly review insight | `archive_monthly_review` | `ArchiveMonthlyReviewSection` |
| Surprise observation | `archive_surprise` | `ArchiveSurprisesSection` |
| Share discoveries list | `share_discoveries_list` | `ArchiveShareDiscoveriesScreen` |

## Card types (analytics `card_type`)

- `belief_change`, `belief_lifecycle`, `contradiction`, `monthly_review_insight`, `surprise_observation`
- Plus V1 list types: `pattern_discovery`, `milestone`, `change_detected`

## Analytics

| Event | When | Properties |
|-------|------|------------|
| `discovery_share_tapped` | User taps **Share Discovery** | `card_type`, `card_id`, `surface` |
| `discovery_shared` | PNG shared successfully | `card_type`, `card_id`, `surface`, `export_method`, `evidence_recording_count` |

## Files

| Area | Path |
|------|------|
| Copy / export size | `lib/features/archive_discovery_share/archive_discovery_share_copy.dart` |
| Model | `lib/features/archive_discovery_share/archive_discovery_share_card_model.dart` |
| Moment builders | `lib/features/archive_discovery_share/archive_discovery_share_moments.dart` |
| List engine | `lib/features/archive_discovery_share/archive_discovery_share_engine.dart` |
| Analytics | `lib/features/archive_discovery_share/archive_discovery_share_analytics.dart` |
| Palettes | `lib/features/archive_discovery_share/archive_discovery_share_palette.dart` |
| Premium card + PNG | `lib/widgets/archive_discovery_share/archive_discovery_share_card.dart` |
| Share sheet | `lib/widgets/archive_discovery_share/share_discovery_sheet.dart` |
| CTA button | `lib/widgets/archive_discovery_share/share_discovery_button.dart` |

## Tests

```bash
cd apps/voicememory_mobile
flutter test test/archive_discovery_share_test.dart test/archive_growth_test.dart
```

## Screenshot paths (integration audit)

When `tool/run_ui_screenshot_audit.sh` includes archive share routes:

- `~/Desktop/upload12/screenshots/archive_discovery_share_card_light.png`
- `~/Desktop/upload12/screenshots/archive_discovery_share_card_dark.png`
- `~/Desktop/upload12/screenshots/archive_discovery_share_sheet.png`

Manual preview: open Archive → contradiction / theory change / surprise → **Share Discovery**.
