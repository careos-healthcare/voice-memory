# ArchiveMe V1 Product Specification

**Canonical promise:** A private voice archive that preserves what you actually said and cautiously shows evidence-backed changes over time.

**Worktree:** `/Users/chiragpatel/Projects/voice-memory-rc-validation-448a5332`  
**Branch:** `cursor/rc-validation-448a5332`  
**Status:** Consolidation in progress — not release-ready until acceptance criteria pass.

## Target customer

People who want a private record of their own words and careful, evidence-backed insight into how their stated beliefs change — without life-coaching, diagnosis, or speculative interpretation.

## V1 capabilities (in scope)

1. Fast voice capture  
2. Fast text capture (`/quick-capture`)  
3. Reliable encrypted private storage  
4. Original transcript archive (`/archive-belief`)  
5. Search (archive home)  
6. Cautious verified patterns and changes (`/belief-changes`)  
7. Exact supporting evidence (`/belief-evidence`)  
8. Correction and suppression controls (proof admission pipeline)  
9. Export (`/export`)  
10. Entry deletion  
11. Account deletion  
12. Optional paid deeper archive history (`/subscription`)

## Primary navigation

| Tab | Route | Screen |
|-----|-------|--------|
| Record | `/record` | RecordScreen |
| Archive | `/archive-belief` | ArchiveBeliefScreen |
| Changes | `/belief-changes` | BeliefChangesScreen |
| Account | `/account` | AccountScreen |

## Free vs paid

See `lib/product/v1_free_paid_capabilities.dart`. Privacy, deletion, export, corrections, and original content remain **free**.

## Quarantined from production graph (V1)

- Capacity-loop products, beta laboratories, missions, tester dashboards  
- Milestone systems, archive packs, competing pattern maps  
- Post-save beta/pro/retention card experiments (via `SurfacePriorityEngine` V1 mode)  
- Startup: objective widgets, check-in reminders, curiosity notifications, beta activation tracker (when `V1FeatureFlags.enableV1Only`)

## Route inventory

- **Before:** 105 `GoRoute` declarations (~1000 lines, 70+ screen imports)
- **After:** ~28 production routes with screen builders + 73 redirect-only quarantine routes
- **Quarantine module:** `lib/router/v1_quarantine_redirects.dart`
- **V1 allowlisted:** 25 customer-facing capabilities in `lib/router/v1_route_inventory.dart`

## Record refactor (started)

- `lib/features/recording/v1/record_view_state.dart` — explicit phase machine  
- Legacy UI remains; V1 post-save capped to one proof card  

## Acceptance criteria (not yet complete)

- [ ] Every production route classified  
- [ ] No quarantined system imported by production startup  
- [ ] Full V1 journey tests pass  
- [ ] Android debug + iOS simulator builds pass  
- [ ] Full `validate_core.sh` pass  

## Deferred (post-V1)

Thought map, archive analyst, action items, widgets, custom reports — gated by `V1FeatureFlags`.
