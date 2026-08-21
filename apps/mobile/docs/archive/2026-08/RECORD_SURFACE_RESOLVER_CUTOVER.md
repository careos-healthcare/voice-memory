# Follow-up: Record surface resolver cutover (P0)

**Status:** Complete — resolver wired via adapter (2026-08-19)  
**Owner:** Mobile recording / capture flow

## Summary

Two parallel implementations compute the same record-screen gate/engine surface:

| Path | Role | Live in production? |
|------|------|---------------------|
| ~~`recording_build_context_assembler.dart`~~ | Deleted | — |
| `recording_build_context_resolver.dart` → `assembleRecordBuildContext` | Builds input, resolves via notifier, adapts to `RecordBuildContext` | **Yes** — called from `recording_state_controller.dart` `build()` |
| `record_surface_resolver.dart` → `RecordSurfaceResolver.resolve` | Pure static resolver; returns `RecordSurfaceViewState` | **Yes** — via `RecordSurfaceResolutionNotifier` |
| `record_surface_resolution_notifier.dart` | Memoizes resolver via `RecordSurfaceInputCacheKey` | **Yes** — wired in `_RecordScreenState` |

Supporting types (`record_surface_input.dart`, `record_surface_flags.dart`, `record_surface_view_state.dart`, `record_surface_input_cache_key.dart`, `record_surface_capture_policy.dart`) are only referenced by the dormant resolver path except where noted below.

## Caller audit (2026-08-19)

```
RecordSurfaceResolver          → record_surface_resolution_notifier, record_surface_input, tests
RecordSurfaceResolutionNotifier → recording_state_controller, tests
assembleRecordBuildContext     → recording_build_context_resolver.dart (adapter path)
```

No other production imports of the resolver/notifier pair.

## Structural relationship

- **Size:** assembler 4,477 lines; resolver 4,454 lines (~1,510 diff hunks, mostly mechanical).
- **Origin:** Resolver is an extracted, testable copy of assembler logic with state read from `RecordSurfaceInput` instead of `_RecordScreenState` fields.
- **Last modified:** resolver 2026-08-18; assembler 2026-08-12 (resolver is newer).

## Behavioral differences (diff-style)

### 1. Side effects (assembler only)

```diff
- if (stack.showFirstRecordingHandoff && !_firstRecordCardTracked) {
-   _firstRecordCardTracked = true;
-   unawaited(ActivationTracker.trackActivationFirstRecordCardShown());
- }
```

Resolver is pure; cutover must fire this telemetry in the controller when handoff becomes visible.

### 2. Visual audit UI override

```diff
- ui = audit.ui;   // assembler mutates local ui from VisualAuditOverrides
+ // resolver keeps input.flags; audit does not override RecordUiState
```

Audit overrides for `entriesAfterSave`, mic phase, errors, etc. are mirrored; **UI phase override differs** unless input is rebuilt with audited ui.

### 3. BuildContext-derived chrome (assembler only)

Assembler computes after engine pass:

- `bottomInset` ← `MediaQuery.paddingOf(context).bottom`
- `showFirstSessionOnboarding` ← `FirstSessionOnboardingStore.shouldShow(...)`
- `showFirstUseWordingHelper` ← `FirstUseWordingGates.shouldShow(...)`
- `showCloseButton` ← `RecordScreenCloseButton.shouldShow(context)`
- `ui` field on `RecordBuildContext`

`RecordSurfaceViewState` has **none** of these. Scaffold/body (`record_screen_scaffold.dart`, `record_screen_body.dart`, `record_pre_capture_cards.dart`) still read them from `RecordBuildContext`.

### 4. Return type shape

- `RecordBuildContext`: includes `ui`, scaffold chrome fields; many fields typed `dynamic` (legacy).
- `RecordSurfaceViewState`: strongly typed; adds `recordLoosenSignals`, `recordReadyProTiming`, `betaActivationPathFinalContext`, `postSaveLoosenSignals`, `postSaveProTiming`, `betaFeedbackCapturePostSaveFinal`, `showRecordCaptureModes`, `base`; omits scaffold chrome.

Cutover options:

1. **Adapter:** `RecordSurfaceViewState` + small `RecordScreenChrome` → existing `RecordBuildContext` (minimal widget churn).
2. **Full migration:** Update all `RecordBuildContext` consumers to `RecordSurfaceViewState` + chrome struct; delete `recording_build_context.dart`.

### 5. Input precomputation

Resolver expects caller to supply:

- `RecordSurfaceFlags.from(ui)` (canRecord, showFraming, phase booleans)
- `compactLayout`, `stackDecision`, pro/mic/session fields on `RecordSurfaceInput`

Assembler computes flags inline from `_ui` and private methods (`_compactLayout`, `_recordStackDecision`).

### 6. Sync note sanitization

Both paths equivalent:

- Assembler: `ConsumerCopyGuard.userFacingSyncNote`
- Resolver: `recordSurfaceSyncNote` (same guard in `record_surface_capture_policy.dart`)

## Recommendation

**Complete the cutover** (do not abandon):

1. Resolver is current, pure, and already covered by unit tests.
2. Dual 4.4k-line files will drift on every record-surface change until one is deleted.
3. Abandoning resolver wastes the extraction work and leaves assembler permanently untestable without widget harness.

**Do not flip the switch until:**

1. `RecordSurfaceInput` builder extracted from `_RecordScreenState` (single mapping site).
2. Side-effect telemetry moved out of resolver path.
3. Scaffold chrome split into explicit struct or kept in thin controller wrapper.
4. Golden/widget recording suite run green (`test/features/recording/`, record goldens, capture-flow gates).

## Suggested cutover sequence

1. Add `_buildRecordSurfaceInput()` on `_RecordScreenState`.
2. Wire `RecordSurfaceResolutionNotifier` in `build()`; map to `RecordBuildContext` via adapter (temporary).
3. Parity test: same input → assembler vs resolver field-by-field on golden fixtures.
4. Switch production to resolver output; delete assembler part file.
5. Shrink `recording_state_controller.dart`; merge `RecordBuildContext` into `RecordSurfaceViewState` when scaffold updated.

## Out of scope for this follow-up

- Capture-flow strangler ADR already lists assembler as legacy (`docs/architecture/ADR_STRANGLER_CAPTURE_FLOW.md`).
- `tool/generate_recording_build_context_parts.mjs` must be updated or retired with assembler deletion.
