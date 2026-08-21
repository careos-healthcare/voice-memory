# Release Evidence Pack

One proof bundle that shows ArchiveMe is ready for TestFlight or App Store submission.

This is **proof only** — not product work. Do not change product UI or purchase logic while collecting evidence.

## Status

| Status | Meaning |
|--------|---------|
| `notReady` | One or more required evidence items are missing |
| `readyForTestFlight` | All required evidence is present; secrets rotation still pending |
| `readyForSubmission` | All required evidence is present and production secrets are rotated |

## Required evidence

Collect proof for each item before calling the release candidate ready:

1. Clean git status
2. Version and build number captured
3. Physical iPhone smoke test
4. Physical iPad smoke test
5. Production API smoke test
6. Voice save path
7. Typed save path
8. First proof path
9. Pro paywall route
10. RevenueCat product load
11. Sandbox purchase
12. Restore purchases
13. Entitlement persistence
14. Support URL
15. Privacy URL
16. Terms URL
17. Screenshots
18. TestFlight uploaded

## Submission gate

- **TestFlight:** all 18 items above
- **Submission:** all 18 items plus production secrets rotated

## Code

- Model: `lib/features/release_evidence/release_evidence_pack.dart`
- Copy: `lib/features/release_evidence/release_evidence_pack_copy.dart`
- Tests: `test/release_evidence_pack_test.dart`

## Usage

```dart
final result = ReleaseEvidencePack.resolve(
  ReleaseEvidencePackInput(
    cleanGitStatus: true,
    versionBuildCaptured: true,
    // ... all evidence booleans
    secretsRotated: false,
  ),
);

// result.status -> notReady | readyForTestFlight | readyForSubmission
// result.missingItems -> deterministic list of gaps
```
