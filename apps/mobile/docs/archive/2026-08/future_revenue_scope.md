# Future revenue scope lock

> Canonical doc: `docs/architecture/future_revenue_scope.md` · Code: `lib/features/future_revenue_scope/`


ArchiveMe V1 ships one paid reason: **Pro keeps the longer proof trail**.

These directions stay **future-only** until TestFlight proof. Do not surface them as live V1 claims.

## Blocked from release surfaces

- Reports
- Exports
- Referrals
- Safe sharing as a growth loop
- Cross-device continuity
- Android expansion
- B2B
- Annual plan
- Premium tiers
- Private reports
- Loop packs
- Contradiction detection
- Archive memory expansion
- Dashboard-like surfaces
- Ranking / importance surfaces

## V1 rules

1. **One Pro promise** — longer proof trail only.
2. **No day-0 paywall** — Pro bridge after first useful proof or explicit open.
3. **No share-to-unlock** — sharing stays explicit and future-gated.
4. **No clinical framing** — no therapy, diagnosis, mental health assessment, or clinical report copy.

## Code modules

- Copy: `lib/features/future_revenue_scope/future_revenue_scope_copy.dart`
- V1 reducer: `lib/features/v1_visible_surface_reducer/`
- Safe sharing future: `lib/features/safe_sharing_future/`
- Tests: `test/future_revenue_scope_test.dart`, `test/v1_visible_surface_reducer_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/future_revenue_scope_test.dart test/v1_visible_surface_reducer_test.dart
```
