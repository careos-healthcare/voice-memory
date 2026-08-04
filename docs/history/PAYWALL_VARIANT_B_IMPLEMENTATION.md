> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Paywall Variant B — Production Implementation

**Default:** Variant B — *What changed in your life?*  
**Positioning:** ArchiveMe sells **evidence of change over time**, not AI or journaling.

Billing and RevenueCat (`pro`) are **unchanged**.

---

## Files changed

| File | Change |
|------|--------|
| `apps/voicememory_mobile/lib/billing/archive_paywall_copy.dart` | Variant B production copy; A/C behind flags |
| `apps/voicememory_mobile/lib/billing/archive_paywall_stats.dart` | Hero, pre-CTA counts (patterns / theories / contradictions) |
| `apps/voicememory_mobile/lib/widgets/archive_paywall/archive_paywall_body.dart` | B layout: hero block, key value section, no theory placeholder |
| `apps/voicememory_mobile/lib/screens/mobile_subscription_screen.dart` | Unchanged billing wiring |
| `apps/voicememory_mobile/lib/widgets/archive_v1/archive_intelligence_upgrade_card.dart` | Uses B headline + `preCtaFor(B)` |
| `apps/voicememory_mobile/lib/features/archive_synthesis/archive_synthesis_pro_gate.dart` | Teaser headline = B |
| `apps/voicememory_mobile/test/archive_paywall_stats_test.dart` | B default + pre-CTA tests |
| `PAYWALL_REDESIGN_PLAN.md` | Default variant note |

---

## Feature flags (A / C testing)

| Flag | Headline | Layout |
|------|----------|--------|
| *(none)* / `PAYWALL_VARIANT=B` | What changed in your life? | **Production B** |
| `PAYWALL_VARIANT=A` | Your archive is starting to understand you. | A locked subtitles + social proof block |
| `PAYWALL_VARIANT=C` | Your archive is just getting started. | B locked cards + key value (C headline only) |

```bash
# Production (default)
flutter run

# Experiments
flutter run --dart-define=PAYWALL_VARIANT=A
flutter run --dart-define=PAYWALL_VARIANT=C
```

---

## Before / after screenshots checklist

Capture at `/subscription` with ≥50 eligible reflections and a visible Archive Theory.

| # | Screen | Before | After (Variant B) |
|---|--------|--------|-------------------|
| 1 | Headline | “Your archive is starting to understand you.” / generic subscription | **What changed in your life?** |
| 2 | Subhead | Single “Generated from…” block | Two paragraphs: tracking patterns → **now sees what changed** |
| 3 | Hero | Inline in subhead | Dedicated **Generated from / across** card |
| 4 | Theory | Placeholder when thin evidence | **Hidden** unless real theory (≥15% conf, ≥3 evidence) |
| 5 | Locked cards | Long-form subtitles | B subtitles (See what changed…) |
| 6 | Mid section | Social proof list | **Key value:** insights over time + 4 bullets |
| 7 | Pre-CTA | “analyzed N recordings…” | **identified: N patterns / M theories / K contradictions** |
| 8 | Primary CTA | Mixed / “View plans” | **Unlock Archive Intelligence** |
| 9 | Secondary | Missing or weak | **Continue with Free Archive** (pops back) |
| 10 | Pro state | Generic subscription active | Archive Intelligence active + back to archive |

**Audit command:** `apps/voicememory_mobile/tool/run_ui_screenshot_audit.sh` (route `/subscription`).

---

## Final copy inventory (Variant B production)

### Chrome
- Screen title: **Archive Intelligence**

### Headline
- **What changed in your life?**

### Subheadline
- Your archive has been tracking patterns, beliefs, and recurring themes across your recordings.
- Now it's starting to see what changed.

### Hero (when ≥5 recordings)
- Generated from
- `{recordingCount} recordings`
- across
- `{timeSpan}` (days / months / years)

### Theory preview (real data only)
- The archive currently believes:
- `"{primaryTheory}"`
- Confidence: `{confidence}%`
- Evidence: `{evidenceCount} recordings`

### Locked section title
- Included with Archive Intelligence

### Locked cards
| Title | Subtitle |
|-------|----------|
| Monthly Review | See what changed this month. |
| Archive Historian | See how your beliefs evolved. |
| Milestone Reviews | What your first 50, 100, and 200 recordings reveal. |
| Archive Intelligence | Evidence-backed synthesis across your archive. |

### Key value
- **The most valuable insights appear over time.**
- Which beliefs strengthened
- Which beliefs disappeared
- Which contradictions emerged
- What keeps repeating across your life

### Pre-CTA
**With data:**
```
The archive has identified:
{patternCount} recurring patterns
{beliefCount} active theories
{contradictionCount} contradictions
```
(Omitted lines when count is 0.)

**Fallback:**
- The archive becomes more valuable as it gathers evidence.

### CTAs
- Primary: **Unlock Archive Intelligence**
- Secondary: **Continue with Free Archive**

### Pro active
- Archive Intelligence is active
- Monthly reviews, historian timelines, milestone insights, and evidence-backed narratives are available on this device.

### Removed / never used
- Premium insights · Unlock AI · AI journal · Voice journal · Powered by GPT-5 · Smarter journaling

---

## Data sources

| UI field | Source |
|----------|--------|
| `recordingCount` | Eligible journal entries |
| `timeSpan` | First → last eligible entry date |
| `primaryTheory` | `ArchiveV1View.theory` |
| `patternCount` | Unique `recurringThemes` across eligible entries |
| `beliefCount` | `theoryRanking` primary + secondary, else 1 if theory present |
| `contradictionCount` | `ArchiveV1View.contradictions.length` |

---

## Validation

```bash
cd apps/voicememory_mobile
flutter test test/archive_paywall_stats_test.dart
flutter analyze lib/billing/archive_paywall_copy.dart lib/billing/archive_paywall_stats.dart lib/widgets/archive_paywall/
```

