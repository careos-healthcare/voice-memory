> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Archive Deep Dive V1 — test plan

## Automated

```bash
cd apps/voicememory_mobile
flutter test test/archive_deep_dive_gate_test.dart test/archive_deep_dive_engine_test.dart
```

## Manual — gating

1. Fresh install / &lt;5 eligible reflections → Archive shows empty state; no **Show me why**.
2. After 5+ reflections with usable transcripts → belief hero appears with **Show me why**.
3. Tap **Show me why** → `/archive-deep-dive` with all sections.

## Manual — sections

| Section | Verify |
|---------|--------|
| Current belief | Statement, confidence, disclaimer (not stated as fact) |
| Why | Summary, recording count, excerpts panel |
| Belief history | First / strongest / latest; THEN / NOW snapshots with excerpts |
| Counter-evidence | For excerpts; against includes contradictions or low-overlap lines |
| Pattern explorer | Themes, connected contradictions, blind spots when present |
| Self-inquiry | Questions match evidence (contradictions → “against”; evolution → “weakened”) |
| Save reflection | Saves journal entry; appears in timeline/journal |
| Belief timeline | First mention, key recordings, evolution widget |

## Manual — secondary entry

- **View Evidence Trail** link on hero (when deep dive available) still opens `/archive-evidence-trail`.

## Deep link

- Navigate to `/archive-deep-dive` without `extra` or with insufficient evidence → insufficient message, no sandbox/QA UI.

