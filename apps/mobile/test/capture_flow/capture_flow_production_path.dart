/// Characterization notes for the strangler capture production path.
///
/// **Voice capture:**
/// 1. Router `/record` → `CaptureScreenHost` → `CaptureScreen`
/// 2. `CaptureFlowController.startVoiceCapture` → `AudioRecorderAdapter`
/// 3. Stop → `LocalMomentRepository.saveVoiceCapture` → `CapturePipelineService.run`
/// 4. Consent via `RemoteConsentPolicy` before remote gateways fire
/// 5. Post-save → `MomentSaveReceiptCard` → Archive CTA
///
/// **Typed capture:**
/// 1. Router `/quick-capture` → `CaptureScreenHost(typed)`
/// 2. `saveTypedCapture` → `LocalMomentRepository.saveTypedCapture`
///
/// **Returning-user:**
/// 1. `/quick-capture?entryId=` → typed attach via `attachTypedToVoiceEntry`
/// 2. Receipt `onCorrectText` → `TranscriptCorrection.open` → `applyTranscriptCorrection`
/// 3. Receipt `onTypeWhatYouSaid` → `PendingTranscriptRecovery.open` → `completeReturningUserSave`
/// 4. Receipt `onRetryRemote` → `retryRemoteProcessing`
/// 5. App resume → `recoverPendingCapture` for interrupted voice drafts
///
/// **Active dependencies:**
/// - `V1AccountDependencies` (recording, pipeline, journalStore, prefs)
/// - `CapturePipelineService` + `RemoteProcessingConsentStore`
/// - `RecordPipelineLog` telemetry
/// - `MomentSaveReceiptCard` (post-save only)
///
/// **Explicitly NOT on this path:**
/// - `recording_dependencies.dart` barrel
/// - `recording_build_context_assembler.dart` engine catalog
library;
