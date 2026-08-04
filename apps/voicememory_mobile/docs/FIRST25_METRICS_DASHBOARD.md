# First 25 Users — Product Validation Dashboard

**Status: NOT VALIDATED.**

**Real users to date: 0 (zero).** Nobody outside the build team has used this
app yet. Every metric below therefore reads `NOT YET MEASURED`. This document
exists to make the measurement possible and to make a later claim checkable — it
does not contain a result, a trend, or a conclusion about product-market fit.

Enforced by `test/product_metrics_test.dart`. That test fails if this file
claims a metric the analytics catalog would reject, if a value cell is filled in
without a real cohort, or if an unmeasured field is written as a zero.

---

## 1. Reading rules

1. `NOT YET MEASURED` means no real user has produced this number. It is not a
   zero. A zero is a measurement claim; absence of measurement is not.
2. Real user metrics live in section 3 and 4. Synthetic results live in section
   6 and are never mixed into section 3.
3. While the real user count is zero, the status of this plan stays exactly
   "not validated", and no threshold in section 5 is an observation.
4. A metric may only be added here if every event id and property key it names
   is registered in `lib/services/analytics/analytics_catalog.dart`. If the
   catalog would reject it, it is not measurable and it does not belong here.
5. Percentages are deliberately absent from this document. There is no real
   denominator yet, so there is no rate to print.
6. Section 4 describes what each registered event means when it fires. It does
   not claim that every emitter is wired at the call site. If an event never
   fires, its metric stays `NOT YET MEASURED`, which is the same honest outcome
   as having no users.

---

## 2. Real user cohort

| Field | Value |
|---|---|
| Real users to date | 0 (zero) |
| Cohort open date | NOT YET MEASURED |
| Cohort close date | NOT YET MEASURED |
| Installs | NOT YET MEASURED |
| Participants who reached a first save | NOT YET MEASURED |
| Paying participants | NOT YET MEASURED |
| Provider invoice period covered | NOT YET MEASURED |

The counts above are unmeasured rather than zero. "Real users to date" is the
one exception: zero users is a fact we know directly, not an inference from
missing data.

---

## 3. Metric registry

Every row names the registered events and property keys that produce it, so the
metric is derivable rather than aspirational. `Current value` is the only column
that may ever hold a measurement, and today every one of them is unmeasured.

| Metric | Registered event ids | Registered property keys | Formula | Data source | Current value |
|---|---|---|---|---|---|
| `first_capture_completion` | `first_capture_started`, `first_capture_saved`, `transcript_reviewed` | `source_type`, `ui_origin`, `performance_duration_band` | saved divided by started | client analytics | NOT YET MEASURED |
| `first_valid_observation_rate` | `first_capture_saved`, `first_valid_observation_delivered` | `conclusion_kind`, `evidence_count_band`, `performance_duration_band` | observation delivered divided by first save | client analytics | NOT YET MEASURED |
| `interpretation_accurate_rate` | `interpretation_feedback_submitted` | `feedback_choice`, `evidence_count_band` | feedback_choice accurate divided by all feedback | client analytics | NOT YET MEASURED |
| `interpretation_miss_rate` | `interpretation_feedback_submitted` | `feedback_choice`, `conclusion_kind` | feedback_choice wrong_angle or too_generic divided by all feedback | client analytics | NOT YET MEASURED |
| `second_entry_within_72h` | `first_capture_saved`, `second_entry_saved` | `time_band`, `source_type` | second save inside three days divided by first save | client analytics | NOT YET MEASURED |
| `first_comparison_within_7d` | `second_entry_saved`, `first_valid_comparison_delivered` | `time_band`, `evidence_count_band` | comparison inside seven days divided by second save | client analytics | NOT YET MEASURED |
| `changes_reopen` | `changes_opened`, `change_thread_opened`, `weekly_review_opened` | `ui_origin`, `change_count_bucket` | two or more Changes sessions divided by one or more | client analytics | NOT YET MEASURED |
| `paywall_after_value` | `first_valid_observation_delivered`, `paywall_shown_after_value` | `access_decision`, `subscription_state`, `ui_origin` | paywall after value divided by observation delivered | client analytics | NOT YET MEASURED |
| `purchase_conversion` | `purchase_started`, `purchase_completed` | `subscription_state`, `access_decision` | purchase completed divided by purchase started | client analytics | NOT YET MEASURED |
| `renewal_rate` | none — store billing export | none — no client property | renewed divided by due to renew | store billing | NOT YET MEASURED |
| `refund_rate` | none — store billing export | none — no client property | refunded divided by completed purchases | store billing | NOT YET MEASURED |
| `provider_cost_per_active_user` | none — provider invoices | none — no client property | invoice total divided by active accounts | provider billing | NOT YET MEASURED |
| `provider_cost_per_paying_user` | none — provider invoices | none — no client property | invoice total divided by paying accounts | provider billing | NOT YET MEASURED |
| `restore_success` | `restore_completed` | `subscription_state`, `access_decision` | restore returning pro_active divided by restore attempts finished | client analytics | NOT YET MEASURED |
| `export_completion` | `export_completed` | `ui_origin`, `entry_count_bucket` | export finished divided by people with a first save | client analytics | NOT YET MEASURED |

The last two rows are supporting signals rather than validation questions. They
are listed because their events are registered and would otherwise go
unwatched.

---

## 4. Metric derivations

### 4.1 First capture completion

Does someone who starts a first capture finish saving it? `first_capture_started`
fires on the first capture attempt of the install; `first_capture_saved` fires
once the moment is persisted. `transcript_reviewed` sits between them and tells
us whether people read the text before saving — it records that a review
happened and carries no transcript. `performance_duration_band` shows whether
slowness is the reason for a drop-off. Current value: NOT YET MEASURED.

### 4.2 First valid observation rate

Does a saved first capture actually produce an evidence-backed observation?
`first_valid_observation_delivered` is emitted only when an observation passes
the existing evidence gate, with `evidence_count_band` recording how much
support it had and `conclusion_kind` recording which kind of claim it was.
Current value: NOT YET MEASURED.

### 4.3 Accurate rate, and 4.4 wrong angle plus too generic rate

Both come from one event, `interpretation_feedback_submitted`, split by
`feedback_choice`. The allowlist is `accurate`, `wrong_angle`, `too_generic`,
`hide`. The accurate rate is the accurate share; the miss rate is the
`wrong_angle` plus `too_generic` share. `hide` is counted in the denominator and
reported separately, because hiding is a rejection of the surface rather than a
judgement about the angle. Current values: NOT YET MEASURED.

### 4.5 Second entry within 72 hours

`second_entry_saved` carries `time_band`, so the three-day window is a band
comparison rather than a timestamp subtraction. Bands counted as inside the
window: `same_session`, `within_24h`, `within_72h`. Current value: NOT YET
MEASURED.

### 4.6 First comparison within seven days

`first_valid_comparison_delivered` also carries `time_band`, measured from the
second save. Bands counted as inside the window: `same_session`, `within_24h`,
`within_72h`, `within_7d`. Current value: NOT YET MEASURED.

### 4.7 Changes reopen

`changes_opened` on each visit, `change_thread_opened` when a specific thread is
read, `weekly_review_opened` for the weekly surface. Reopen means two or more
`changes_opened` sessions by the same install. `ui_origin` separates a deliberate
visit from one that followed a save. Current value: NOT YET MEASURED.

### 4.8 Paywall after value

`paywall_shown_after_value` is only correct if it never fires before
`first_valid_observation_delivered`. `access_decision` records why the gate
appeared (`allowed`, `denied_pro_required`, `denied_quota`,
`denied_not_eligible`) and `subscription_state` records the state the person was
in. Current value: NOT YET MEASURED.

### 4.9 Purchase

`purchase_started` to `purchase_completed`. Client analytics can show intent and
completion inside the app; it is not the source of truth for money. Current
value: NOT YET MEASURED.

### 4.10 Renewal, and 4.11 refund

There is no client event for either, and there must not be one: a renewal or a
refund is a billing fact that happens outside the app, often long after the last
session. Both come from the store billing export (App Store Connect and Google
Play, reconciled through the subscription provider). Client analytics can only
show a later `subscription_state` of `pro_active` or `pro_grace`, which is a
weak correlate and is never reported as a renewal. Current values: NOT YET
MEASURED.

### 4.12 Provider cost per active and per paying user

Numerator: the transcription and analysis provider invoices for the period.
Denominator: active accounts and paying accounts counted server side. The client
emits no cost or spend property at all, and the analytics payloads carry no
account identifier, so this metric cannot be produced from the funnel events by
design. Current values: NOT YET MEASURED.

---

## 5. Pre-registered decision thresholds

**These are targets chosen in advance. They are not observations, and writing one
here does not make it true.** They are recorded now so that a later result cannot
be graded against a threshold invented after seeing the data.

| Metric | Threshold to keep going |
|---|---|
| `first_capture_completion` | 4 of every 5 who start a capture save it |
| `first_valid_observation_rate` | 4 of every 5 first saves get an observation |
| `interpretation_accurate_rate` | at least 3 of every 5 ratings say accurate |
| `interpretation_miss_rate` | fewer than 1 of every 5 ratings say wrong angle or too generic |
| `second_entry_within_72h` | at least 2 of every 5 people save again inside three days |
| `first_comparison_within_7d` | at least 3 of every 5 second savers see a comparison |
| `changes_reopen` | at least 2 of every 5 people who open Changes come back |
| `purchase_conversion` | at least 1 of every 4 started purchases completes |
| `provider_cost_per_active_user` | provider cost stays under one fifth of the subscription price |

Every threshold above is a decision rule with no measurement behind it yet.

---

## 6. Synthetic test results — NOT USER EVIDENCE

**This section is not user evidence, is not a result, and must never be quoted
as one.** Nothing in it says whether the product works. It only says whether the
measurement plumbing works.

Source: `test/product_metrics_test.dart`, which builds a fixture cohort of
invented participants whose archives are filled with sentinel text.

What the synthetic cohort proves:

- The cohort export builds, validates, and serialises for a fixture cohort.
- No sentinel string from a fixture archive appears anywhere in the export.
- Two fixture archives that differ only in their text produce a byte-identical
  export.
- Every event id and property key named in section 3 is accepted by the
  analytics catalog and survives the `ProductAnalytics` guard.
- An empty cohort produces empty distributions rather than invented zeros.

What the synthetic cohort does not prove: anything about real behaviour,
retention, willingness to pay, accuracy of observations, or cost.

---

## 7. Cohort export

`lib/features/product_metrics/product_metrics_cohort_export.dart` produces the
analysis file. It is content-free by construction: it counts, bands, and maps
enums, and it never copies a string out of an archive.

Top level:

| Field | Meaning |
|---|---|
| `schema`, `schema_version` | fixed identifiers for the export shape |
| `no_user_text` | flag asserting the substance exclusion below |
| `real_user_cohort` | flag; `0` while the cohort is synthetic |
| `participant_count_bucket` | cohort size as a catalogued count bucket |
| `participants` | one band-only row per participant |
| `funnel_steps` | per registered event id, the bucketed number of participants who reached it |
| `first_observation_latency` | distribution over `performance_duration_band` |
| `second_entry_latency` | distribution over `time_band` |
| `first_comparison_latency` | distribution over `time_band` |
| `interpretation_feedback` | distribution over `feedback_choice` |
| `paywall_access` | distribution over `access_decision` |
| `subscription_mix` | distribution over `subscription_state` |

A participant row carries only `source_type`, `subscription_state`,
`entry_count_bucket`, `reviewed_entry_count_bucket`, `reflection_count_bucket`,
`evidence_count_band`, `change_count_bucket`, `changes_open_count_bucket`,
`has_first_proof`, `has_change`, and `has_strong_evidence`.

Excluded by construction, and rejected by the validator if a future edit tries
to add them: transcripts, quotes, topics, thread labels, structured marker text,
correction notes, prompts, generated questions, conclusion wording, inferred
sensitive categories, entry or account identifiers, timestamps, raw durations,
and raw counts.

The guarantee is enforced in one place, `_validate`, which walks the assembled
payload and throws unless every key is a registered analytics property, a
structural container, or a `_count_bucket` key, and every value is a catalogued
band, a catalogued flag, or a catalogued event id. It mirrors the final provider
guard in `ProductAnalytics` so that a mistake fails loudly instead of shipping.

---

## 8. What is not measured, and why

| Not measured | Why |
|---|---|
| Every metric in section 3 | Real users to date: 0. There is no cohort to measure. |
| Cohort dates, installs, paying participants | No cohort has opened. |
| Renewal and refund | No client event exists, by design, and no billing period has closed. |
| Provider cost per active or paying user | No invoice period has been reconciled, and no account is active. |
| Time to first observation in the field | Only measurable once real captures exist; the band property is instrumented and idle. |
| Any comparison between cohorts | One cohort does not exist yet, so two cannot be compared. |

Nothing in this document is a result. When the first cohort closes, values
replace `NOT YET MEASURED` in section 3 only, section 6 stays separate, and the
thresholds in section 5 stay exactly as they are written today.
