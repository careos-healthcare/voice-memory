# V1 Release Checklist

## Product graph

- [ ] `tool/validate_v1_production_graph.sh` passes
- [ ] `tool/audit_v1_launch_product.sh` passes
- [ ] `flutter test test/v1_launch_product_contract_test.dart` passes
- [ ] No `archiveme_research` imports in `lib/`
- [ ] All production route builders ⊆ `V1ProductionAllowlist.productionRouterScreens`

## Core journey (manual)

- [ ] Record voice → save → see in Archive with original transcript
- [ ] Type capture → attach/save
- [ ] Search archive
- [ ] Open cautious change with exact evidence quotes
- [ ] Correct or suppress interpretation
- [ ] Export archive
- [ ] Delete entry and delete account (with confirmations)
- [ ] Paywall shows real prices, restore, cancellation copy; usable at 300% text scale

## Builds (physical device / store gates — external)

- [ ] iOS release build on device
- [ ] Android release build with production signing
- [ ] App Store / Play metadata matches V1 promise (no quarantined feature claims)
- [ ] RevenueCat products match paywall copy

## Automated gates in repo

```bash
cd apps/voicememory_mobile
bash tool/validate_v1_production_graph.sh
bash tool/audit_v1_launch_product.sh
flutter test test/v1_launch_product_contract_test.dart test/v1_production_allowlist_test.dart test/v1_navigation_guard_test.dart test/v1_paywall_wiring_test.dart test/paywall_accessibility_test.dart
```

## Known pre-existing gaps

- Full `flutter test` suite has unrelated failures
- `proof_scope_account_switch_test` `_admittedProof` fixture (2 tests)
- Physical device and store submission require manual verification outside CI
