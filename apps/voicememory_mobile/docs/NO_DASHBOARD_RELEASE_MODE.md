# No dashboard release mode v1

Prevent V1 from feeling like a **life dashboard**. Classification and release-surface policy only — no UI layout changes unless an existing policy hook allows it.

## Risky surfaces

- Archive health
- Action plan
- Evidence map
- Workspace quick actions
- Reports
- Dashboard
- Context insights
- Monthly review
- Archive analyst

## Allowed surfaces

- Record
- Type instead
- Prompt assist
- Post-save reinforcement
- First proof
- Why proof appeared
- Confirm or correct
- What changed
- Evidence Trail
- Pro longer trail

## Rules

1. In release mode, risky surfaces hide unless the user explicitly asked or the surface directly supports first proof.
2. Never call ArchiveMe a dashboard, command center, second brain, or life OS.
3. Prefer proof trail language.
4. No UI layout change unless an existing policy hook allows it.
5. No new product features.

## Low-risk secondary exception

`shareProof` may appear when the user explicitly asks — still not a dashboard surface.

## Decisions

| Decision | Meaning |
| --- | --- |
| `hardened` | Risky surfaces stay hidden in release mode |
| `violated` | A risky surface is visible in release mode |

## Code module

`lib/features/no_dashboard_release_mode/no_dashboard_release_mode.dart`

Composes `V1VisibleSurfaceReducer`, `NoDashboardPositioningGuard`, and `ProductionNavigation.hideIncompleteSurfaces`.

## Guardrail

Do not call ArchiveMe a dashboard, command center, second brain, or life OS. No UI layout changes unless an existing policy hook allows it. No new features.

## Related docs

- [V1_VISIBLE_SURFACE_REDUCER.md](V1_VISIBLE_SURFACE_REDUCER.md) — underlying surface reducer
- [no_dashboard_positioning_guard.md](no_dashboard_positioning_guard.md) — copy guard for dashboard drift
