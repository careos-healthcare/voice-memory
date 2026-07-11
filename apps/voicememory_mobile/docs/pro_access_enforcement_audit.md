# Pro access enforcement audit v1

Clarify what Pro access is actually enforced, what is not, and what blocks production vs TestFlight. **Audit only** — no account system, backend sync, or purchase behavior changes.

## Classifications

| Classification | Meaning |
| --- | --- |
| `enforcedLocally` | Client-side gate, cache, or privacy lock |
| `enforcedByRevenueCat` | Store receipt / entitlement from RevenueCat |
| `notEnforcedYet` | Documented gap in current architecture |
| `acceptableForTestFlight` | Gap is OK while RevenueCat is not live or mechanics are supplementary |
| `productionBlocker` | Broken purchase, restore, or entitlement mechanics |

## Audit dimensions (8)

1. **RevenueCat entitlement active** — `enforcedByRevenueCat` when live and readable; `productionBlocker` when live but broken
2. **Restore entitlement** — `enforcedByRevenueCat` when restore path verified; `productionBlocker` when broken
3. **Local entitlement cache** — `enforcedLocally` via `BillingService.mergeEntitlements` stale-cache guard
4. **Reinstall behavior** — local cache when persistence verified; otherwise restore via RevenueCat
5. **Account identity linked to billing** — `notEnforcedYet` (`RevenueCat logIn` not wired to auth today)
6. **Device and Family Sharing prevention** — `notEnforcedYet` (platform + identity limits)
7. **Server-side entitlement check** — supplementary `enforcedLocally` when present; `notEnforcedYet` when absent
8. **Privacy lock separate from Pro** — `enforcedLocally` (`AppLockService` is device-local, not Pro-gated)

## Decisions

| Decision | Meaning |
| --- | --- |
| `testFlightAcceptable` | Purchase/restore/entitlement not broken; documented gaps remain |
| `productionBlocked` | At least one `productionBlocker` item |
| `enforcementDocumented` | No blockers; enforcement posture fully classified |

## Bridges

- `fromStoreReadinessInput()` — maps `StoreReadinessSingleSourceInput` billing signals without duplicating store readiness logic

## Code modules

- Engine: `lib/features/pro_access_enforcement/pro_access_enforcement_audit.dart`
- Copy: `lib/features/pro_access_enforcement/pro_access_enforcement_audit_copy.dart`
- Tests: `test/pro_access_enforcement_audit_test.dart`

## Related docs

- `docs/ACCESS_PROTECTION_AUDIT.md` — auth, app lock, restore copy
- `docs/STORE_READINESS_SINGLE_SOURCE.md` — canonical store checklist
- `REVENUECAT_PRODUCTION_AUDIT.md` — RevenueCat wiring gaps

## Rules

- Audit only. Do not build account system.
- Do not add backend/sync.
- Do not block TestFlight unless purchase, restore, or entitlement is broken.

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/pro_access_enforcement_audit_test.dart
```

Included in `tool/validate_core.sh`.

## v2 additions

- **Developer dashboard** — `ProAccessEnforcementAuditCard` on Internal diagnostics (`/developer-diagnostics`)
- **Local signals bridge** — `ProAccessEnforcementAuditV2.buildFromLocalSignals()` maps RevenueCat diagnostics, entitlement cache, backend config, and app lock state
- **CI bundle** — `tool/run_pro_access_enforcement_audit.sh`

### v2 code modules

- Dashboard + CI v2: `lib/features/pro_access_enforcement/pro_access_enforcement_audit_v2.dart`
- Developer card: `lib/widgets/debug/pro_access_enforcement_audit_card.dart`

### Run CI bundle

```bash
cd apps/voicememory_mobile
bash tool/run_pro_access_enforcement_audit.sh
```
