> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Archive Analyst V1 — test plan

## Automated tests

```bash
cd apps/voicememory_mobile
flutter test test/archive_analyst_gate_test.dart test/archive_analyst_confidence_test.dart test/archive_analyst_engine_test.dart
```

| Test file | Covers |
|-----------|--------|
| `archive_analyst_gate_test.dart` | 50 / 100 / 200 thresholds, insufficient state |
| `archive_analyst_confidence_test.dart` | Score decreases with counter + stale |
| `archive_analyst_engine_test.dart` | Report at 50+ entries, competing beliefs, debates |

## Confidence algorithm (verification)

See `archive_analyst_confidence_engine.dart` doc comment.

Manual checks:

- Belief with many supporting mentions → higher confidence than sparse belief.
- Same belief with added counter recordings → confidence drops.
- Belief only in early months → lower than belief with recent mentions.

## Manual QA checklist

### Gating

- [ ] &lt; 50 eligible transcripts → `/archive-analyst` shows “We need more evidence.”
- [ ] 50–99 → Level 1 title, limited list sizes (4 current, 2 emerging/fading).
- [ ] 100–199 → Level 2, larger lists.
- [ ] 200+ → Level 3, full depth.

### Sections (50+)

- [ ] **Current beliefs** — statement, confidence %, evidence + counter counts, last updated.
- [ ] **Emerging** — trend series when mentions increase over months.
- [ ] **Fading** — decline copy when mentions drop.
- [ ] **Contradictions** — from V1 (when present).
- [ ] **Blind spots** — from V1 (when present).
- [ ] **Competing beliefs** — primary + alternatives with % (not single narrative).
- [ ] **Archive debate** — FOR/AGAINST excerpts + counts; “View recording” opens entry.
- [ ] **Evidence summary** — reflection count, date span.

### Tone

- [ ] No “you should”, “journey”, “heal”, or coaching language.
- [ ] Disclaimer: interpretation, challengeable.

### Navigation

- [ ] Archive → menu → **Archive Analyst** → report.
- [ ] Pull-to-refresh rebuilds report.

## Files changed

| Path | Change |
|------|--------|
| `ARCHIVE_ANALYST_PLAN.md` | Plan |
| `ARCHIVE_ANALYST_TEST_PLAN.md` | This file |
| `lib/features/archive_analyst/archive_analyst_gate.dart` | Gating |
| `lib/features/archive_analyst/archive_analyst_confidence_engine.dart` | Confidence |
| `lib/features/archive_analyst/archive_analyst_belief_catalog.dart` | Candidates |
| `lib/features/archive_analyst/archive_analyst_models.dart` | Types |
| `lib/features/archive_analyst/archive_analyst_engine.dart` | Report builder |
| `lib/features/archive_analyst/archive_analyst_copy.dart` | Copy |
| `lib/screens/archive_analyst_screen.dart` | UI |
| `lib/router/app_router.dart` | `/archive-analyst` |
| `lib/widgets/archive_detail_drawer.dart` | Nav link |
| `test/archive_analyst_gate_test.dart` | Tests |
| `test/archive_analyst_confidence_test.dart` | Tests |
| `test/archive_analyst_engine_test.dart` | Tests |

