# ADR: Strangler refactor of the recording controller

**Date:** 2026-08-12  
**Status:** Accepted (slice 2 — returning-user + flag removal)  
**Scope:** `apps/mobile/lib/features/capture_flow/`

## Context

The legacy `recording_state_controller.dart` (~1,900+ lines as a `part of` a much larger recording graph) coordinates capture together with dozens of post-save retention engines, pattern cards, and experimental surfaces. Focused beta needs a maintainable core path: local save first, optional remote processing after consent, single post-save receipt, archive handoff.

Rewriting the entire controller in one change is unsafe and unreviewable.

## Decision

Adopt a **strangler fig** pattern:

1. **Characterize** the production path for voice + typed capture (permissions → record/stop or typed save → local persist → optional remote → receipt → archive).
2. **Introduce** a typed immutable state machine (`CaptureFlowController`) with narrow ports (audio, local repository, consent, remote gateways, recovery store, telemetry, transcript correction).
3. **Render** through a bounded `CaptureScreen` (<300 lines) with extracted panels and the existing `MomentSaveReceiptCard` for post-save.
4. **Route** all focused-beta capture through `CaptureScreenHost` — no rollback flag.
5. **Archive** legacy `RecordScreen` from the production graph; keep in-tree for tests and dedicated review (`LEGACY_ARCHIVED.md`).

## Production path

| Step | Component |
|------|-----------|
| Router `/record` | `CaptureScreenHost` → `CaptureScreen` |
| Router `/quick-capture` | `CaptureScreenHost(typed, optional attachToEntryId)` |
| Permission | `AudioRecorderAdapter` → `RecordingService` |
| Voice stop | `LocalMomentRepository.saveVoiceCapture` → `CapturePipelineService.run` |
| Typed save / attach | `saveTypedCapture` / `attachTypedToVoiceEntry` |
| Returning-user receipt | `TranscriptCorrection`, `PendingTranscriptRecovery`, remote retry |
| Consent gate | `RemoteConsentPolicy` / gateways before remote work |
| Post-save UI | `MomentSaveReceiptCard` |
| Archive CTA | `context.go('/archive-belief')` |

## Legacy archival

See `docs/architecture/recording.md`. Automatic deletion of the 11k-line controller is **not** part of this slice — requires dedicated review after two green releases.

## Dependency delta

**New path imports:** `V1AccountDependencies`, `CapturePipelineService`, `RecordingService`, `RemoteProcessingConsentStore`, `JournalStore`, `RecordPipelineLog`, post-save receipt widgets, capture UI panels, transcript correction / pending recovery sheets.

**Excluded from new path (legacy only):** `recording_dependencies.dart` barrel, `record_surface_resolver.dart` engine catalog (record screen), post-save engine catalog.
