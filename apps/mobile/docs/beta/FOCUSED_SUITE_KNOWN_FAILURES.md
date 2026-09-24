# Focused suite — known failures

Re-run of the `LAUNCH_VALIDATION.md` suite on 24 Sep 2026: **244 passed, 35 failed, 13s**.

The August baseline was 269 passed and 15 failed. The extra failures are the same kind of check: the suite still expects the public name ArchiveMe, and the shipped name is Thoughtprint.

## The 15 from August

| # | Test | This run |
| --- | --- | --- |
| 1 | consumer_ui_copy has no VoiceMemory | Fails on `ARCHIVEME NOTICED`, not VoiceMemory. Stale brand assertion. |
| 2 | privacy_copy_policy has no VoiceMemory | Passed. |
| 3 | first save card stays calm | Passed. |
| 4 | share-safe proof excludes transcripts | Still fails in the batch. The August isolated re-run passed; the batch failure was an async prefs write. |
| 5 | 1-entry workspace is not noisy | Passed. |
| 6 | 2-entry workspace shows comparison guidance | Passed. |
| 7 | first-run copy uses ArchiveMe | Fails because the sentence says Thoughtprint. Stale brand assertion. |
| 8 | RevenueCat unconfigured copy stays calm | Copy checks pass. Settings no longer tells someone that purchases are unavailable (`isConfigured` / `SubscriptionCopy.temporarilyUnavailable` are gone). Product bug, left as-is. |
| 9 | next-evidence plan card on the belief screen | The wiring check passed. The copy check fails because it still looks for ArchiveMe. |
| 10 | watchlist card on the belief screen | Same: wiring passed, ArchiveMe copy check failed. |
| 11 | depth card on the belief screen | Same: wiring passed, ArchiveMe copy check failed. |
| 12 | milestones card on the belief screen | Same: wiring passed, ArchiveMe copy check failed. |
| 13 | 0-entry home mentions the sample archive | Fails because the sentence says Thoughtprint and does not contain "archiveme". |
| 14 | 1-entry next action explains the second moment | Passed. |
| 15 | paywall safe message when billing is not configured | Passed. The screen says plans are not available, and the free archive stays usable. |

## Paywall signal

`pwrun/before.txt`: **365 tests, 257 passed, 108 failed** on the custom paywall.

The purchase surface that ships is `RevenueCatPaywallPresenter`. About 10 tests stay on that surface (presenter, restore, closed proof gate, subscription-review copy, golden, 2x text). The other paywall files are in `test/legacy_quarantine/` and skipped by the `legacy` tag in `dart_test.yaml`.
