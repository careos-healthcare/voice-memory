# V1 Data Flow

End-to-end path for the launch product. See also `docs/V1_ARCHITECTURE_TRACE.md`.

```text
capture → save → verify → display → correct → sync → delete → purchase
```

## 1. Capture

- **Voice:** `RecordScreen` → `CapturePipelineService`
- **Text:** `QuickTextCaptureScreen` → same pipeline attach path
- **Scope:** `AccountSessionGuard` on async pipeline runs
- **Storage:** Local audio vault (optional recovery when live voice disabled)

## 2. Save

- **Store:** `JournalStore` (encrypted at rest per account namespace)
- **Failure:** Local-only save path; user-facing calm copy, no raw exceptions

## 3. Verify

- **Pipeline:** Proof admission in `CapturePipelineService`
- **Remote processing:** Gated by shared `RemoteProcessingConsentStore`
- **Labeling:** Verified vs local-only clearly distinguished in UI

## 4. Display

- **Archive:** `ArchiveBeliefRepository` → lazy sliver list
- **Changes:** `BeliefChangesScreen` — only admitted proofs
- **Evidence:** `BeliefEvidenceScreen` — exact quotes + dates

## 5. Correct / suppress

- **Canonical store:** `ArchiveCorrectionStore` via `archive_correction_bootstrap.dart`
- **UI:** Entry detail memory surfacing, verified proof correction controls
- **Legacy:** `CorrectionMemoryStore` not loaded on V1 Record

## 6. Sync

- **Service:** `SyncService` / encrypted coordinator (optional, account tab)
- **Cursor:** Incremental pull via change sequence in prefs
- **Startup:** Non-blocking optional phase

## 7. Delete

- **Entry:** `PrivateDataService.deleteEntrySecurely`
- **Account:** `DeleteAccountScreen` — server then optional local wipe

## 8. Purchase (optional)

- **Controller:** `PaywallController` — side effects outside `build`
- **Scope:** Deeper history only; never blocks export/correction/deletion
