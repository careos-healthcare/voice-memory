# First 25 User Metrics Dashboard

Early-cohort funnel for the first ~25 beta users. Events fire to **Firebase Analytics** via `ProductAnalytics` on mobile (`apps/voicememory_mobile`).

**Implementation:** `lib/features/first25/`

---

## Activation

First signal that someone captured real archive evidence.

| Event | When it fires | Parameters |
|-------|----------------|------------|
| `recording_created` | First eligible save of a new reflection (non-draft transcript) | `entry_id`, `source` |
| `recording_day1` | Eligible recording on **calendar day ≥ 1** after first recording anchor | `entry_id`, `cohort_day` |
| `recording_day3` | Same, day offset ≥ 3 (once) | `entry_id`, `cohort_day` |
| `recording_day7` | Same, day offset ≥ 7 (once) | `entry_id`, `cohort_day` |

**Sources (`source`):** `voice_capture`, `text_capture`, `offline_voice_capture`, `offline_text_capture`, `deep_dive_inquiry`, `journal_save`

**Firebase funnel (suggested):**

```
recording_created → recording_day1 → recording_day3 → recording_day7
```

**Activation rate (manual):**

- **D1 recording retention** = users with `recording_day1` / users with `recording_created`
- **Weekly recording habit** = users with `recording_day7` / users with `recording_created`

**Cohort anchor:** stored in app prefs (`first25RecordingRetention.firstRecordingAt`) — first eligible recording timestamp (UTC calendar days).

---

## Retention

Return visits to the archive home and continued recording milestones (see Activation day events).

| Event | When it fires | Parameters |
|-------|----------------|------------|
| `archive_opened` | Archive tab load completes | `surface`: `archive_belief_v1`, `archive_belief`, `archive_belief_empty` |

**Retention proxies:**

| Metric | Formula |
|--------|---------|
| Archive revisit | Count `archive_opened` per user (≥ 2 sessions) |
| D1 / D3 / D7 recording | See Activation day events |

**Note:** `archive_opened` fires once per successful load (including empty archive). Filter `surface != archive_belief_empty` for “returned with content.”

---

## Conversion

Value-moment paywall + subscription screen.

| Event | When it fires | Parameters |
|-------|----------------|------------|
| `paywall_seen` | Value-moment card renders, or subscription screen loads for non-Pro | `surface`, optional `variant` |
| `paywall_dismissed` | “Not now” on value-moment paywall | `surface` |
| `paywall_started` | CTA to plans / purchase button tapped | `surface`, optional `period` (`monthly` / `yearly`) |
| `paywall_purchased` | RevenueCat purchase returns Pro | `surface`, optional `period` |

**Surfaces (`surface`):**

- `value_moment_blindSpot`, `value_moment_discover`, `value_moment_archiveContinuity`
- `subscription_screen`

**Conversion funnel:**

```
paywall_seen → paywall_started → paywall_purchased
```

**Rates:**

| Metric | Formula |
|--------|---------|
| Paywall impression → start | `paywall_started` / `paywall_seen` |
| Start → purchase | `paywall_purchased` / `paywall_started` |
| Impression → purchase | `paywall_purchased` / `paywall_seen` |
| Dismiss rate | `paywall_dismissed` / `paywall_seen` (value-moment only) |

**Legacy events (still emitted):** `discovery_share_tapped`, `discovery_shared`, `paywall_proof_seen` — not part of First25 core dashboard.

---

## Archive engagement

Depth beyond opening the tab — theory, evidence, deep dive, sharing.

| Event | When it fires | Parameters |
|-------|----------------|------------|
| `evidence_opened` | “Why am I seeing this?” evidence sheet opens | `surface` (e.g. `archive_theory`, `archive_contradiction`) |
| `theory_opened` | Theory hero “Why am I seeing this?” before sheet | `surface`: `archive_theory` |
| `deep_dive_opened` | Deep dive screen opens or theory “Show me why” CTA | `surface`: `archive_deep_dive_screen`, `archive_theory_cta` |
| `share_card_opened` | Share discovery bottom sheet opens | `surface`, `card_type` |
| `share_card_shared` | PNG shared successfully | `surface`, `card_type`, `export_method` |

**Engagement funnel:**

```
archive_opened → theory_opened → evidence_opened → deep_dive_opened
```

**Sharing funnel:**

```
share_card_opened → share_card_shared
```

**Engagement scorecard (first 25 users):**

| Signal | Event |
|--------|--------|
| Saw theory | `theory_opened` |
| Opened evidence | `evidence_opened` |
| Went deep | `deep_dive_opened` |
| Shared a discovery | `share_card_shared` |

---

## Firebase console setup

1. **Custom definitions** — mark `recording_day1`, `recording_day7`, `paywall_purchased` as key events.
2. **Funnel explorations** — use tables above (Activation, Conversion, Archive engagement).
3. **Audience** — first 25 installs: filter by `first_open` date range of beta period OR by `user_id` allowlist.
4. **DebugView** — run debug build; events log as `analytics:<event>` in console when Firebase is configured.

---

## Code map

| File | Role |
|------|------|
| `first25_user_metrics.dart` | Event names + `ProductAnalytics.trackStrings` |
| `first25_recording_retention.dart` | D1/D3/D7 one-time milestones |
| `first25_journal_hooks.dart` | Journal save → activation/retention |
| `journal_store.dart` | Calls hooks on new eligible saves |
| `archive_belief_screen.dart` | `archive_opened` |
| `evidence_trail_navigation.dart` | `evidence_opened` |
| `archive_v1_body.dart` | `theory_opened`, `deep_dive_opened` (CTA) |
| `archive_deep_dive_screen.dart` | `deep_dive_opened` |
| `value_moment_paywall.dart` | `paywall_seen` / `dismissed` / `started` |
| `mobile_subscription_screen.dart` | `paywall_seen` / `started` / `purchased` |
| `share_discovery_sheet.dart` | `share_card_opened` |
| `archive_discovery_share_analytics.dart` | `share_card_shared` (+ legacy `discovery_shared`) |

---

## Tests

```bash
cd apps/voicememory_mobile
flutter test test/first25_user_metrics_test.dart
```

---

## First-25 snapshot template

Fill from Firebase after beta week:

| Pillar | Metric | Target (example) | Actual |
|--------|--------|------------------|--------|
| Activation | % with `recording_created` | 100% of installs that record | |
| Activation | D1 `recording_day1` | ≥ 40% | |
| Retention | ≥ 2 `archive_opened` | ≥ 50% | |
| Conversion | `paywall_purchased` / `paywall_seen` | TBD | |
| Archive | `deep_dive_opened` / `archive_opened` | TBD | |
| Archive | `share_card_shared` | TBD | |

---

*Generated for ArchiveMe mobile — event names are stable for cross-build comparison in the first beta cohort.*
