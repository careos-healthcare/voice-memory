# Beta decision dashboard specification

**Purpose:** Operator-facing spec for focused-beta go/no-go — **not** an in-app dashboard.  
**Data source:** Firebase/BigQuery export of `beta_analytics_v1` registry events + local QA export when needed.

## North-star panel

### Useful Evidence Week (derived metric)

**Definition:** In a calendar week (UTC), user has:

1. ≥2 `first_moment_saved_local` / subsequent save events (count distinct durable saves that week), **and**
2. ≥1 `possible_pattern_viewed` or `evidence_opened`, **and**
3. ≥1 `pattern_reviewed` where `review_outcome` ∈ `{fits, partly_fits, corrected}`.

| Display | Required |
|---------|----------|
| Numerator | Users meeting all three criteria in the week |
| Denominator | Users with ≥1 durable save in the week |
| Also show | Raw counts (not % only) |

Example row: `Useful Evidence Week — 12 / 84 saved users (14.3%)`

---

## Activation funnel panels

Each row shows **count / eligible denominator**. Percentages are secondary.

| Step | Numerator event | Denominator |
|------|-----------------|-------------|
| Onboarding seen | `onboarding_viewed` | App installs (platform) |
| Capture intent | `capture_intent_selected` | `onboarding_viewed` |
| First save | `first_moment_saved_local` | `capture_intent_selected` OR `onboarding_viewed` |
| Archive opened | `archive_first_viewed` | `first_moment_saved_local` |
| Second save (72h) | `second_moment_saved_72h` where `within_window=true` | `first_moment_saved_local` |
| Third save (7d) | `third_moment_saved_7d` where `within_window=true` | `first_moment_saved_local` |
| Pattern eligible | `possible_pattern_eligible` | `third_moment_saved_7d` |
| Pattern viewed | `possible_pattern_viewed` | `possible_pattern_eligible` |
| Evidence opened | `evidence_opened` | `possible_pattern_viewed` |
| Pattern reviewed (validated) | `pattern_reviewed` ∈ {fits, partly_fits, corrected} | `possible_pattern_viewed` |

### Review outcome breakdown (when denominator ≥ `possible_pattern_viewed`)

Show raw counts for each `review_outcome`:

- `fits`
- `partly_fits`
- `not_for_me`
- `corrected`
- `hidden`

---

## Retention panel (derived)

| Metric | Numerator | Denominator |
|--------|-----------|-------------|
| Retained capture D7 | `retained_capture_d7` | `first_moment_saved_local` |
| Retained capture D30 | `retained_capture_d30` | `first_moment_saved_local` |

Show `cohort_day` distribution as a histogram bucket (median / p75), not individual timestamps.

---

## Trust / reliability panel

| Metric | Display |
|--------|---------|
| Local save success rate | `local_save_result.result=success` / all `local_save_result` |
| Remote processing success | `remote_processing_result.result=success` / (`success`+`failure`), exclude `skipped` from failure rate |
| Consent grant rate | `consent_decision.decision=grant` / all consent decisions at onboarding |
| Prohibited remote attempts | Count of `prohibited_remote_attempt_after_decline` — **must be 0** in production |
| Export success | `export_result.result=success` / all export |
| Deletion success | `deletion_result.result=success` / all deletion |
| Recovery success | `app_recovery_result.result=success` / all recovery |

Include latency bucket stacked bars for `local_save_result` and `remote_processing_result` (structural buckets only).

---

## Cohort filters

- Install week (UTC)
- Platform (iOS)
- Build channel: TestFlight vs App Store
- Remote consent granted at onboarding: yes / no / unknown

---

## Decision thresholds (starting points — tune with N≥30)

| Signal | Green | Red |
|--------|-------|-----|
| First save / onboarding | ≥35% | <20% |
| Second save within 72h / first save | ≥25% | <10% |
| Third save within 7d / first save | ≥15% | <5% |
| Pattern reviewed (validated) / pattern viewed | ≥30% | <10% |
| Useful Evidence Week / weekly saved users | ≥10% | <3% |
| Prohibited remote attempts | 0 | >0 |

---

## Explicit non-goals (do not build for beta decision)

- Module generation counts
- Revenue readiness / paywall funnel dashboards
- Vanity “insight quality” percentages without denominators
- Any dashboard requiring transcript, correction text, or entry ids

These remain in beta-mission local tooling (`ArchiveBetaMissionGate`) for engineering diagnostics only.
