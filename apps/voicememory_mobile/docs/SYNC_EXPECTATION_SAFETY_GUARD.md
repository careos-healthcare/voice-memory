# Sync Expectation Safety Guard v1

Prevent paid copy from implying **cloud backup** or **cross-device sync** unless sync is actually proven.

## Goal

Keep TestFlight and paid copy honest when sync is unavailable. Paid promise stays **longer proof trail**, not backup.

## Blocked copy (unless `syncProven`)

- cloud backup
- cross-device sync
- access everywhere
- never lose your archive
- backed up automatically
- account keeps your trail safe
- sync across devices

## Allowed copy

- on this device
- local archive
- private on this device
- Pro keeps the longer proof trail
- sync not available yet
- backup/export only where true

Honest negation/guardrail lines also pass, e.g. `Do not claim cloud backup` and `Sync not available yet`.

## Key rules

- **No backend/sync implementation**
- **Copy guard only**
- Paid promise remains **longer proof trail**, not backup
- TestFlight copy must be honest if sync is unavailable

## API

```dart
SyncExpectationSafetyGuard.evaluate(copy, syncProven: false);
SyncExpectationSafetyGuard.passes(copy, syncProven: false);
```

When `syncProven` is `true`, blocked phrases are allowed for audited builds only.

## Code modules

- Engine: `lib/features/sync_expectation_safety/sync_expectation_safety_guard.dart`
- Copy: `lib/features/sync_expectation_safety/sync_expectation_safety_copy.dart`
- Tests: `test/sync_expectation_safety_guard_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/sync_expectation_safety_guard_test.dart
```
