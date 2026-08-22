# Beta analytics event registry

**Schema:** `beta_analytics_v1`  
**Code:** `apps/mobile/lib/features/beta_analytics/`  
**North-star (derived):** **Useful Evidence Week** — ≥2 moments saved in a calendar week AND a possible pattern/change viewed with review outcome `fits`, `partly_fits`, or `corrected`.

## Identity

| Phase | Behavior |
|-------|----------|
| Anonymous / local (focused beta) | Milestone timestamps in `MobilePrefsStore`; Firebase receives registry events with structural enums only. No account id, email, or content-derived ids. |
| Account-linked analytics | **Not enabled** in focused beta. A future decision would require explicit opt-in and a separate registry version. |

## Consent boundary

- `consent_decision` records **remote processing** purposes (`remote_transcription`, `remote_reflection`) only.
- Declining remote processing does **not** block local beta analytics.
- Recording `consent_decision` never performs a remote network call.
- Product analytics (Firebase) is gated to registry events in [ProductAnalytics](../apps/mobile/lib/services/product_analytics.dart).

---

## Activation funnel events

| Event | Owner | Trigger | Payload | Retention | Deletion |
|-------|-------|---------|---------|-----------|----------|
| `onboarding_viewed` | activation | OnboardingScreen mounts | `surface=onboarding` | 90d | Cohort counts |
| `capture_intent_selected` | activation | Voice/typed intent selected | `intent=voice\|typed` | 90d | Cohort counts |
| `first_moment_saved_local` | activation | After encrypted/local write (count=1) | `capture_kind=voice\|typed\|typed_attach` | 365d | Anonymized; local timestamp for windows |
| `archive_first_viewed` | activation | First ArchiveBeliefScreen visit | `surface=archive` | 90d | Cohort counts |
| `second_moment_saved_72h` | activation | After durable 2nd save | `within_window=true\|false` | 365d | Anonymized |
| `third_moment_saved_7d` | activation | After durable 3rd save (pattern minimum) | `within_window=true\|false` | 365d | Anonymized |
| `possible_pattern_eligible` | evidence | ≥3 admitted moments per policy | `policy_version` (int) | 365d | Anonymized |
| `possible_pattern_viewed` | evidence | Eligible pattern/change surface shown | `surface=archive_changes\|post_save\|changes_tab\|record` | 365d | Anonymized |
| `evidence_opened` | evidence | Evidence trail opened with eligible content | `surface=belief_evidence\|entry_detail\|export_preview` | 365d | Anonymized |
| `pattern_reviewed` | evidence | After ArchiveCorrectionStore durable write | `review_outcome=fits\|partly_fits\|not_for_me\|corrected\|hidden` | 365d | Outcome enum only |

## Derived retention (local aggregate)

| Event | Owner | Trigger | Payload | Notes |
|-------|-------|---------|---------|-------|
| `retained_capture_d7` | retention | Local deriver: 2+ saves, day ≥7 from first | `cohort_day` | Emitted once when criterion met |
| `retained_capture_d30` | retention | Local deriver: 2+ saves, day ≥30 from first | `cohort_day` | Emitted once when criterion met |

## Trust / reliability events

| Event | Owner | Trigger | Payload |
|-------|-------|---------|---------|
| `consent_decision` | trust | Onboarding/settings consent persist | `purpose`, `decision=grant\|decline\|revoke` |
| `prohibited_remote_attempt_after_decline` | trust | Audit before remote I/O without consent | `purpose` |
| `local_save_result` | trust | Capture local persist completes | `result`, `capture_kind`, `latency_bucket` |
| `remote_processing_result` | trust | Remote stage completes/skips | `result=success\|failure\|skipped`, `kind`, `latency_bucket` |
| `export_result` | trust | Export share completes/fails | `result=success\|failure` |
| `deletion_result` | trust | Local/account deletion completes | `result`, `scope=local_archive\|account` |
| `app_recovery_result` | trust | Pending capture recovery | `result`, `reason_bucket` |

**Latency buckets:** `sub_500ms`, `ms_500_2s`, `s_2_5`, `s_5_plus`, `unknown`

---

## Forbidden payload content

Never emit: audio, transcript, correction text, generated text, content-derived hashes, local paths, evidence text, tokens, raw provider errors.

Validated by `BetaAnalyticsPayloadValidator` + `ProofAnalyticsGuard` + sentinel tests.

---

## Removed from production Firebase graph

The following **no longer reach Firebase** in release builds (local beta-mission analysis may still use them via `BetaActivationSummaryTracker` when `ArchiveBetaMissionGate` is enabled):

### ActivationFunnelAnalytics (100+ vanity funnel events)

Including but not limited to:

- `first_recording_saved`, `first_save_rescue_saved`, `first_recording_sample_saved`
- `first_session_card_seen`, `record_cta_tapped`, `day_1_complete_seen`
- `value_feedback_useful`, `paywall_seen`, `purchase_started`, `purchase_completed`
- All Tier-4 experiment funnel events in `activation_funnel_analytics.dart`

### Legacy ActivationTracker / V1 camelCase events

- `firstReflectionSaved`, `secondReflectionSaved`, `thirdReflectionSaved`
- `firstPatternShown`, `comparisonViewed`, `usefulnessYes`, etc.

These remain in deferred/local stores for historical QA export only.

### In-app vanity dashboards (not production analytics)

- `RevenueReadinessDashboardV2Engine` / `RevenueReadinessCard`
- `TestFlightMetricsDashboardCard`
- `BetaConversionDiagnosisCard`

Reachable only when `ArchiveBetaMissionGate.isEnabled` (TestFlight dart-define or developer unlock) — not App Store release default.

---

## Tests

- `test/features/beta_analytics/beta_analytics_milestone_test.dart`
- `test/features/beta_analytics/beta_analytics_consent_boundary_test.dart`
- `test/proof_admission/proof_analytics_guard_test.dart` (existing sentinel coverage)
