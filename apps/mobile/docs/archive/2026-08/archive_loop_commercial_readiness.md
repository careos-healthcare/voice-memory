# Archive loop commercial readiness

ArchiveMe loop-map Pro commercial wiring status.

## Ready when

- [ ] RevenueCat configures with `REVENUECAT_IOS_API_KEY` or `REVENUECAT_API_KEY`
- [ ] Paywall loads a product and shows price
- [ ] Sandbox purchase unlocks `archive_loop_pro`
- [ ] Restore purchases works
- [ ] Entitlement persists across app restart (cache + RevenueCat refresh)
- [ ] First activation remains free (3 recordings, first map, one edit, one return check)
- [ ] Missing API key does not break release smoke
- [ ] ArchiveMe log hygiene passes on all test and device logs (strict scanner)

## Remaining blockers

| Blocker | Status | Notes |
|---------|--------|-------|
| RevenueCat sandbox purchase | **Not completed** | Blocked until `REVENUECAT_IOS_API_KEY` is exported and sandbox E2E or manual checklist passes |
| App Store / TestFlight build | **Not submitted** | Required before external beta billing validation |
| Production secrets / Stripe rotation | **Required before launch** | Rotate any exposed secrets before production launch |

## RevenueCat sandbox acceptance

When the key is set, sandbox validation must confirm:

1. Product loads from RevenueCat
2. Price appears on paywall
3. Purchase starts (StoreKit sheet)
4. Sandbox purchase succeeds (automated E2E or manual checklist)
5. `archive_loop_pro` entitlement becomes active
6. Gated edit / evidence action unlocks
7. Restore purchases works
8. Entitlement persists after restart or cache reload

```bash
export REVENUECAT_IOS_API_KEY="appl_xxx"
bash tool/run_archive_loop_revenuecat_sandbox_ipad.sh
```

Manual fallback: [revenuecat_sandbox_manual_test.md](revenuecat_sandbox_manual_test.md)

## Entitlement model

| Layer | Id | Purpose |
|-------|-----|---------|
| RevenueCat | `archive_loop_pro` (primary), `pro` (legacy) | Store billing |
| Local prefs | `archiveLoopEntitlement` | Free-tier counters after first loop |

## Gated after first activation (free tier)

- Second loop map
- More than 3 evidence saves
- More than 1 node edit
- More than 1 return check

## Never gated

- First recording
- First instant preview
- Rescue path
- First full map
- First clarity upgrade
- First validation feedback

## Log hygiene (FinalCommercialGate)

Strict scanner (`tool/check_archive_copy_logs.dart`) fails on **any** `ARCHIVEME_` line containing glued tokens, including:

- `alternativeconnector`, `reliefconnector`
- `needs towork`, `towork`, `separateuseful`
- `to=alternativeconnector`, `to=reliefconnector`
- `to=<node>connector=` glued log keys

Normalized log emitters:

- `ARCHIVEME_COPY_MINIMUM_BAR`
- `ARCHIVEME_PATTERN_DISPLAY_COPY_CHECK`
- `ARCHIVEME_PATTERN_COPY_QUALITY`
- `ARCHIVEME_THOUGHT_MAP_LINK_DISPLAYED` (`from=` `to=` `connector=`)

## Validation commands

```bash
flutter test test/archive_copy_pipeline_log_hygiene_test.dart \
  test/revenuecat_archive_loop_entitlement_test.dart \
  test/archive_loop_paywall_test.dart \
  test/guided_loop_prompts_test.dart \
  > /tmp/archive_final_commercial_gate_test.log

dart run tool/check_archive_copy_logs.dart /tmp/archive_final_commercial_gate_test.log

bash tool/run_archive_loop_release_smoke_ipad.sh
bash tool/run_archive_loop_activation_paywall_ipad.sh

export REVENUECAT_IOS_API_KEY="appl_xxx"
bash tool/run_archive_loop_revenuecat_sandbox_ipad.sh
```

## Manual sandbox

See [revenuecat_sandbox_manual_test.md](revenuecat_sandbox_manual_test.md).
