# recording

> Canonical doc: `docs/architecture/recording.md` · Legacy code: `lib/features/recording/`

Production capture lives in `lib/features/capture_flow/` — see [ADR_STRANGLER_CAPTURE_FLOW](ADR_STRANGLER_CAPTURE_FLOW.md).

<!-- from lib/features/recording/REFACTORING_PLAN.md -->

# Recording State Build — Architectural Decomposition Plan

Target: decompose `recording_state_build.dart` (~7,778 lines) into modular files under `lib/features/recording/`.

## Current responsibilities (tangled in monolith)

| Responsibility | Current location | Notes |
|----------------|------------------|-------|
| UI state machine dispatch | `recording_state_build.dart` | `RecordUiState` switch → `_buildRecordScreenBody` |
| Riverpod audio duration listener | `recording_state_build.dart` | Auto-stop via `RecordingDurationPolicy` |
| Visual audit overrides | `recording_state_build.dart` | `VisualAuditOverrides.peekRecordPresentation()` |
| Mic permission presentation | `recording_state_build_sections.dart` + build body | Blocked panel, inline text journal |
| Session / capture controllers | `v1/recording_session_controller.dart` etc. | Already extracted |
| Post-save engine orchestration | `recording_state_build.dart` L68–4172 | ~200+ gate/engine `final` bindings |
| Retention / loop / pattern cards | `recording_state_build.dart` L4174–7777 | Conditional card stacks |
| Primary capture CTA row | `recording_state_post_build.dart` | `_buildBottomActions` |
| Capture mode actions | `recording_state_handlers.dart` | `_buildCaptureEntryActions` |
| Stack / compact layout policy | `recording_state_handlers.dart` | `_recordStackDecision`, `_compactLayout` |
| Audio visualizer + status | `recording_audio_visualizer.dart` | `_RecordingStatusCard` |
| Transcription overlay | `recording_transcription_view.dart` | Live transcript |

## Target file structure

### Coordination & state (Step 2)

- [x] `v1/recording_session_controller.dart` — duration, session phase
- [x] `v1/microphone_permission_controller.dart` — mic phase / denial
- [x] `v1/capture_processing_controller.dart` — pipeline stage labels
- [x] `v1/post_save_result_controller.dart` — post-save titles / flags
- [x] `v1/record_screen_view_model.dart` — view-state aggregation
- [x] `recording_state_controller.dart` — `_RecordScreenState` fields + lifecycle
- [x] `recording_state_handlers.dart` — user actions, save/stop/permission
- [x] `recording_build_context.dart` — immutable snapshot of computed gate/engine outputs
- [x] `recording_build_context_resolver.dart` + `record_build_context_adapter.dart` — resolver path → `RecordBuildContext`
- [x] `recording_audio_listener.dart` — Riverpod `recordingServiceProvider` subscription (auto-stop)

### UI dispatch (Step 3)

- [x] `recording_state_build_dispatch.dart` — `_buildRecordScreen` UI-state switch only
- [x] `views/record_screen_scaffold.dart` — `ColoredBox` / `SafeArea` / scroll shell
- [x] `views/record_pre_capture_cards.dart` — ready-state onboarding / returning-user cards
- [x] `views/record_post_save_cards.dart` — done-state payoff / retention card stack
- [x] `views/record_screen_body.dart` — composes scaffold + sections + bottom actions
- [x] `widgets/recording_controls_widget.dart` — mic CTA row + policy buttons (from `_buildBottomActions`)
- [x] `widgets/recording_capture_actions_widget.dart` — voice/text/live capture entry row
- [x] `widgets/recording_permission_panel.dart` — blocked mic recovery panel
- [x] `recording_state_build_sections.dart` — primary capture state section
- [x] `recording_state_build_ui_flags.dart` — `_RecordUiFlags`
- [x] `recording_audio_visualizer.dart` — waveform + status card
- [x] `widgets/recording_mode_toggle.dart`

### Entry point (Step 4)

- [x] `recording_screen.dart` — public `RecordScreen` widget + `part` barrel (coordinator only)
- [x] `screens/record_screen.dart` — re-export shim for router backward compatibility
- [x] Delete slimmed `recording_state_build.dart` after wiring (file already absent)

### Tests (Step 5)

- [x] `flutter analyze lib/features/recording/ lib/screens/record_screen.dart`
- [x] `flutter test test/record_* test/v1_record_* test/recording_*`

## Extraction order

1. **Context resolver** — `RecordSurfaceResolver` + adapter replaces assembler (complete)
2. **Layout view** — move L4174–7777 widget tree into `views/record_screen_body.dart`
3. **Controls widget** — extract `_buildBottomActions` → `widgets/recording_controls_widget.dart`
4. **Coordinator** — `recording_screen.dart` owns `part` directives; `record_screen.dart` re-exports
5. **Verify** — run record test suite

## Dependency rules

- Widgets receive `RecordBuildContext` + callback typedefs — no direct `_RecordScreenState` access in `views/` / `widgets/`
- Controllers remain injectable via `RecordScreen` constructor + `V1AccountDependencies`
- All `part of` files consolidate under `recording_screen.dart` until callback surface is fully typed


---

<!-- from lib/features/recording/LEGACY_ARCHIVED.md -->

# Legacy recording controller — archived from production

**Status:** Archived (2026-08-12)  
**Production entry:** `CaptureScreenHost` → `CaptureScreen` → `CaptureFlowController`

## What changed

- Router `/record` and `/quick-capture` no longer build `RecordScreen` or `QuickTextCaptureScreen`.
- Rollback flag `enableStranglerCaptureFlow` removed after returning-user migration (correction, retry, recovery, typed attach).
- `RecordScreen` remains in-tree for characterization tests and dedicated review only.

## Unreachable from production graph

These files are not imported by `lib/features/capture_flow/` or production router builders:

- `recording_state_controller.dart` and `part` files (post-save engine catalog)
- ~~`recording_build_context_assembler.dart`~~ (deleted — replaced by resolver + adapter)
- `recording_dependencies.dart` barrel (capture flow uses narrow ports instead)

## Deletion criteria (not automatic)

Delete or further split legacy code only after:

1. Two consecutive green release trains on `CaptureScreenHost`.
2. Dependency graph test confirms no production import of legacy orchestration.
3. Dedicated human review of remaining test-only usages.
