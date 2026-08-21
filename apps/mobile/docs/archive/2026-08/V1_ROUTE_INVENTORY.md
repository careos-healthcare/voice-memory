# V1 Route Inventory

**Authoritative Dart source:** `lib/router/v1_route_inventory.dart`  
**Router:** `lib/router/app_router.dart`

## Before / after consolidation

| Metric | Before | After (V1) |
|--------|--------|------------|
| GoRoute declarations | ~105 | ~28 builders + 73 redirects |
| Primary tabs | Mixed / experimental | 4 (Record, Archive, Changes, Account) |
| Quarantined deep links | Unsafe or dead-end | Redirect to `/record` or `/archive-belief` |

## Core shell (4 tabs)

| Tab | Path | Screen | Capability |
|-----|------|--------|------------|
| Record | `/record` | RecordScreen | voice capture |
| Archive | `/archive-belief` | ArchiveBeliefScreen | transcripts, search |
| Changes | `/belief-changes` | BeliefChangesScreen | cautious patterns |
| Account | `/account` | AccountScreen | storage, export, deletion |

## Supporting routes

Onboarding, entry detail, quick capture, belief evidence/detail, settings, security, privacy, terms, about, export, delete account, support, auth, guest migration.

## Paid routes (build-time gated)

`/subscription`, `/pricing`, `/restore-purchases`

## Quarantine (redirect only)

`/capacity-loop`, `/beta-feedback`, `/journal`, `/pattern-map`, `/weekly-archive-review`, `/yesterdays-snapshot`, `/archive-analyst`, `/moments`, `/testing-archiveme`, and 60+ additional lab paths — see `v1_quarantine_redirects.dart`.

## Navigation guard

`V1NavigationGuard` blocks programmatic navigation to quarantined paths when `enableV1Only` is true.
