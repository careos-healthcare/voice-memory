# V1 visible surface reducer

> Canonical doc: `docs/architecture/v1_visible_surface_reducer.md` · Code: `lib/features/v1_visible_surface_reducer/`


Make the first-release visible product smaller **without deleting existing features**.

## V1 product

- Save one repeat
- Feel it mattered
- ArchiveMe compares later
- First useful proof
- Pro keeps the longer proof trail

## Surfaces (25)

| Surface | Base decision |
| --- | --- |
| `recordCapture`, `typeInstead`, `promptAssist` | `showCore` |
| `postSaveReinforcement` | `showCore` after save |
| `restorePurchases`, `privacySupport`, `archiveHome` | `showCore` |
| `firstProof`, `whyProofAppeared`, `confirmCorrect`, `whatChanged`, `proLongerTrail` | `allowAfterProof` |
| `shareProof` | `allowOnlyWhenUserAsked` |
| `developerDiagnostics` | `developerOnly` |
| `archiveHealth`, `evidenceMap`, `reports`, `actionItems`, `archivePacks`, `archiveAnalyst`, `widgets`, `contextExpansion`, `dashboard`, `search`, `monthlyReview` | `hideForV1` |

## Gating rules

1. Always show `recordCapture`, `typeInstead`, `promptAssist`.
2. Show `postSaveReinforcement` immediately after save.
3. Show `firstProof` only when proof guard says it is safe.
4. Show `whyProofAppeared` and `confirmCorrect` only after first proof.
5. Show `whatChanged` after confirmed repeat or eligible moment.
6. Show `proLongerTrail` only after first proof or proof value.
7. Allow `restorePurchases` and `privacySupport` as release essentials.
8. Hide secondary surfaces from the first journey.
9. Allow `shareProof` only when user explicitly asks.
10. `developerDiagnostics` is developer-only.

## Freeze rules

- **Do not delete features**
- **Do not change record layout**
- **Do not change proof thresholds, anchors, purchase, restore, RevenueCat, backend, sync, or storage**
- **Future revenue directions** (reports, exports, referrals, safe sharing growth loop, B2B, annual, premium tiers) stay hidden until TestFlight proof — see `docs/architecture/future_revenue_scope.md`

## Code modules

- Engine: `lib/features/v1_visible_surface_reducer/v1_visible_surface_reducer.dart`
- Copy: `lib/features/v1_visible_surface_reducer/v1_visible_surface_reducer_copy.dart`
- Tests: `test/v1_visible_surface_reducer_test.dart`

## CI bundle

`tool/run_v1_visible_surface_reducer.sh` runs:

- `test/v1_visible_surface_reducer_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/v1_visible_surface_reducer_test.dart
```
