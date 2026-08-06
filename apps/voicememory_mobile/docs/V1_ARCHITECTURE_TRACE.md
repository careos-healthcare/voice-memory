# V1 architecture trace

Concise map of the production launch loop. Deferred experiments live in
`packages/archiveme_research/` and `lib/router/v1_quarantine_redirects.dart` —
not in the V1 dependency graph.

## End-to-end flow

```text
capture → save → verify → display → correct → sync → delete → purchase
```

| Step | Controller / surface | Repository / store | Account scope | Privacy boundary | Persistence | Failure behavior | Tests |
|------|----------------------|--------------------|---------------|------------------|-------------|------------------|-------|
| **Capture** | `RecordingSessionController`, `MicrophonePermissionController`, `CaptureProcessingController`, `RecordScreenViewModel` | `CapturePipelineService`, `LocalAudioVault` | `AccountSessionScope` on async pipeline | Mic consent + optional remote processing consent | Local audio vault + journal draft | Permission blocked UI; recoverable capture errors | `v1_record_controllers_wiring_test.dart`, record widget tests |
| **Save** | `CaptureProcessingController`, `PostSaveResultController` | `JournalStore`, atomic batch writer | Account namespace via session guard | No raw exceptions to UI | Encrypted local journal | Local-only save path; retry on vault errors | `v1_record_post_save_surface_test.dart` |
| **Verify** | Proof verification in capture pipeline | Server `/api/journal` + local proof fields | Session cookie per account | Verified vs local-only labeling | Entry metadata | Cautious pattern surfacing only when verified | `release_evidence_pack_test.dart` |
| **Display** | `ArchiveBeliefViewModel`, `ArchiveBeliefRepository`, evidence screens | `JournalStore` queries | Account-scoped reads | Archive lock / biometric gate | Lazy sliver list reads | Empty states; no research dashboards in release | `v1_archive_belief_split_test.dart`, `first_archive_state_test.dart` |
| **Correct** | Correction + suppression flows on entry detail | `JournalStore` mutations | Account guard on writes | User-initiated only | Atomic local update + sync log | Optimistic UI with rollback | privacy + delete-account tests |
| **Sync** | `EncryptedSyncService` | `MobilePrefsStore.lastSyncSequence`, server change log | Per-account cursor | Encrypted payload only | Incremental pull/push | Best-effort background; no blocking startup | incremental sync tests (Phase 3) |
| **Delete** | `DeleteAccountScreen`, export flows | `JournalStore`, secure storage wipe | Full account teardown | Confirmation copy + export offer | Local wipe then server | Completed message; no stale session | `delete_account_confirmation_test.dart` |
| **Purchase** | `PaywallController`, `PaywallOfferingsLoader` | RevenueCat / `BillingService` | Entitlement per store account | No analytics during build | Cached entitlement | Unavailable store UI; restore path | `v1_paywall_controller_test.dart`, `paywall_restore_test.dart` |

## Dependency scopes

| Scope | Examples | Rule |
|-------|----------|------|
| Device-global | `DeviceIdStore`, `SecureStorageService`, `LocalAudioVault` | Process lifetime; no account data |
| Account-scoped | `JournalStore`, `EncryptedSyncService`, `BillingService` | Namespace keyed to signed-in account |
| Flow-scoped | `RecordScreenViewModel`, `PaywallController`, `RecordingRecoveryController` | Constructed per screen/flow; no `AppServices.instance` in new V1 code |

See `lib/core/di/v1_dependency_scopes.dart` and `test/v1_dependency_scopes_test.dart`.

## Production graph enforcement

| Check | Script / test |
|-------|----------------|
| Launch capabilities & routes | `lib/core/config/v1_production_allowlist.dart`, `test/v1_production_allowlist_test.dart` |
| Deferred routes quarantined | `tool/validate_v1_production_graph.sh`, `test/v1_router_graph_reduction_test.dart` |
| Native permissions | `docs/V1_PERMISSION_MATRIX.md`, `tool/audit_v1_permissions.sh` |
| Research package isolation | `tool/validate_no_research_imports.sh` |
| Feature module approval | `tool/v1_registered_feature_modules.txt` |

## Staged startup

Implemented in `lib/startup/v1_startup_coordinator.dart`:

1. **Privacy-safe shell** — `ArchiveMeBootstrapApp` first frame; fixed copy on failure (`ConsumerUiCopy.startupLocalStorageFailedBody`), never raw exceptions
2. **Essential local archive** — `AppServices.initializeEssential()`, correction bootstrap, onboarding gate
3. **V1 navigation** — `ArchiveMeApp` / `MainShell` after essential phases complete
4. **Optional async services** — `AppServices.initializeOptionalServices()` + vault recovery (when enabled), billing, analytics — `unawaited` after tabs render

Canonical correction persistence: `ArchiveCorrectionStore` via `reconcileArchiveCorrectionStoreForActiveNamespace`. Legacy `CorrectionMemoryStore` / `CurrentRelevanceStore` are not loaded on V1 Record when `enableV1Only` is true.

Remote processing consent: one `RemoteProcessingConsentStore` per account namespace, shared by `CapturePipelineService` and `RemoteProcessingConsentGate`.

## Exit gates (Phase 4)

- [ ] Release `lib/` imports no `archiveme_research`
- [ ] `app_router.dart` builders ⊆ `V1ProductionAllowlist.productionRouterScreens`
- [ ] Deep links for disabled capabilities redirect to V1 destinations
- [ ] Recording controllers wired through `RecordScreenViewModel`
- [ ] Paywall side effects only in `PaywallController`, not widget `build`
- [ ] `flutter analyze lib/` clean; focused V1 tests green in CI
- [ ] Full suite trend improving; no new service-locator usage on migrated paths
