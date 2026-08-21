# Action items suppression hardening v1

Ensure action items remain **secondary** and cannot enter first journey, Pro promise, onboarding, or first proof.

## Canonical rules

1. Action items are never part of first five minutes
2. Action items are never part of Pro promise
3. Action items are never required onboarding
4. Action items never block first proof
5. Action items never appear as a task manager
6. Remember-this path stays user-confirmed only
7. No reminders expansion
8. No task manager language
9. No new surfaces
10. Action item storage is preserved

## Decisions

| Decision | Meaning |
| --- | --- |
| `hardened` | All suppression rules pass |
| `needsReview` | Remember-this access needs manual review |
| `violated` | Action items are drifting into core journeys |

## Key rules

- **First five minutes:** action items stay hidden until the user asks
- **Pro promise:** no action-items benefit language
- **Onboarding:** no required remember-this step
- **First proof:** action items never block proof surfaces
- **Task manager:** blocked copy and positioning
- **Remember this:** user-confirmed only — no auto-extraction
- **Storage:** do not delete `ActionItemStore`

## Code module

`lib/features/action_items_v1_gate/action_items_suppression_hardening.dart`

Composes `ActionItemsV1SecondaryGate` with explicit suppression rules and repo-signal detectors.

## Guardrail

Do not delete action item storage. No reminders expansion. No task manager language. No new surfaces.

## Related docs

- [action_items_v1_secondary_gate.md](action_items_v1_secondary_gate.md) — underlying secondary gate checks
