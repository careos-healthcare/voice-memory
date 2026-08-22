import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/audio/recording_types.dart' show RecordingException;
import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_dependencies.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_log.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_transition_guard.dart';
import 'package:archiveme_mobile/features/capture_flow/routine/routine_kind_resolver.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_capability_policy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:flutter/foundation.dart';

/// Coordinates focused-beta capture without legacy post-save engines.
class CaptureFlowController extends ChangeNotifier {
  CaptureFlowController(
    this._deps, {
    String? attachToEntryId,
    JournalRoutineKind? routineKindOverride,
    Future<void> Function()? stopBackgroundCapture,
  }) : _attachToEntryId = attachToEntryId?.trim(),
       _routineKindOverride = routineKindOverride,
       _stopBackgroundCapture = stopBackgroundCapture;

  final CaptureFlowDependencies _deps;
  final String? _attachToEntryId;
  final JournalRoutineKind? _routineKindOverride;
  final Future<void> Function()? _stopBackgroundCapture;

  var _backgroundCaptureUi = false;

  CaptureFlowSnapshot _snapshot = const CaptureFlowSnapshot(
    phase: CaptureFlowPhase.ready,
  );

  StreamSubscription<int>? _durationSubscription;
  StreamSubscription<PipelineState>? _pipelineStageSubscription;
  StreamSubscription<VadSegmentEvent>? _thoughtSegmentSubscription;
  final Set<String> _enqueuedThoughtSegmentPaths = {};
  var _streamingThoughtSegmentsSaved = 0;
  bool _disposed = false;

  CaptureFlowSnapshot get snapshot => _snapshot;

  Future<void> initialize() async {
    final count = await _deps.moments.entryCount();
    var snapshot = _snapshot.copyWith(
      entryCount: count,
      attachToEntryId: _attachToEntryId,
      inputMode: _attachToEntryId != null
          ? CaptureInputMode.typed
          : _snapshot.inputMode,
    );
    if (_attachToEntryId != null) {
      final entry = await _deps.moments.loadEntry(_attachToEntryId!);
      if (entry != null) {
        snapshot = snapshot.copyWith(savedEntry: entry);
      }
    }
    _emit(snapshot);
    _pipelineStageSubscription ??=
        _deps.moments.pipelineStates.listen((state) {
      if (_disposed) return;
      _onPipelineStage(state.stage);
    });
    if (_attachToEntryId == null) {
      await _loadRoutinePrompt();
    }
    await _recoverPendingIfNeeded();
  }

  void dismissRoutinePrompt() {
    if (_snapshot.routinePromptDismissed) return;
    _emit(_snapshot.copyWith(routinePromptDismissed: true));
  }

  Future<void> _loadRoutinePrompt() async {
    final anchor = await _deps.routineAnchors.loadLatest();
    final routine = RoutineKindResolver.resolve(
      explicit: _routineKindOverride,
      routineAnchor: anchor,
    );
    _emit(
      _snapshot.copyWith(
        routineKind: routine,
        routinePromptLoading: true,
        routinePromptDismissed: false,
      ),
    );

    try {
      final prompt = await _deps.routinePrompts.loadPrompt(routine: routine);
      if (_disposed) return;
      _emit(
        _snapshot.copyWith(
          routinePrompt: prompt,
          routinePromptLoading: false,
        ),
      );
    } on Object {
      if (_disposed) return;
      _emit(
        _snapshot.copyWith(
          routinePromptLoading: false,
          clearRoutinePrompt: true,
        ),
      );
    }
  }

  Future<void> refreshEntryCount() async {
    final count = await _deps.moments.entryCount();
    _emit(_snapshot.copyWith(entryCount: count));
  }

  void setInputMode(CaptureInputMode mode) {
    if (_snapshot.isBusy || _snapshot.showsPostSave) return;
    unawaited(
      BetaAnalyticsHooks.captureIntentSelected(
        voice: mode == CaptureInputMode.voice,
      ),
    );
    _emit(_snapshot.copyWith(inputMode: mode, clearError: true));
  }

  void showBackgroundRecordingUi() {
    if (_snapshot.phase == CaptureFlowPhase.recording) return;
    _backgroundCaptureUi = true;
    _emit(
      _snapshot.copyWith(
        phase: CaptureFlowPhase.recording,
        recordingDuration: Duration.zero,
        clearError: true,
      ),
    );
  }

  Future<void> startVoiceCapture() async {
    if (!_transition(CaptureFlowPhase.requestingPermission)) return;
    _emit(
      _snapshot.copyWith(clearError: true, permissionBlocked: false),
    );

    var resolution = await _deps.audio.evaluatePermission();
    _deps.telemetry.permissionChecked(status: resolution.state.name);

    if (!resolution.isRecordable) {
      resolution = await _deps.audio.requestPermission();
      _deps.telemetry.permissionRequested(status: resolution.state.name);
    }

    if (!resolution.isRecordable) {
      _emit(
        _snapshot.copyWith(
          phase: CaptureFlowPhase.ready,
          permissionBlocked:
              resolution.state == MicrophonePermissionState.deniedCanAskAgain,
          permissionRequiresSettings:
              resolution.state == MicrophonePermissionState.deniedOpenSettings,
          errorMessage: MicrophonePermissionCopy.deniedBody,
        ),
      );
      return;
    }

    if (!_transition(CaptureFlowPhase.recording)) return;
    try {
      _enqueuedThoughtSegmentPaths.clear();
      _streamingThoughtSegmentsSaved = 0;
      await _thoughtSegmentSubscription?.cancel();
      _thoughtSegmentSubscription =
          _deps.audio.thoughtSegmentEvents?.listen((event) {
        unawaited(_enqueueThoughtSegment(event.segment));
      });
      await _deps.audio.startRecording(permissionVerified: true);
      _deps.telemetry.recorderStarted(success: true);
      _durationSubscription?.cancel();
      _durationSubscription = _deps.audio.durationSeconds.listen((seconds) {
        _emit(
          _snapshot.copyWith(
            recordingDuration: Duration(seconds: seconds),
          ),
        );
      });
      _emit(
        _snapshot.copyWith(
          phase: CaptureFlowPhase.recording,
          recordingDuration: Duration.zero,
          clearError: true,
        ),
      );
    } catch (e, stackTrace) {
      CaptureFlowLog.unexpectedFailure(
        operation: 'start_voice_capture',
        error: e,
        stackTrace: stackTrace,
      );
      _deps.telemetry.recorderStarted(success: false);
      _failRecoverable(
        VoiceCaptureCopy.recordingFailed,
        hasLocalDraft: false,
        hasLocalSave: false,
      );
    }
  }

  Future<void> cancelVoiceCapture() async {
    if (_backgroundCaptureUi) {
      _backgroundCaptureUi = false;
      if (_stopBackgroundCapture != null) {
        await _stopBackgroundCapture!();
      }
      _emit(
        _snapshot.copyWith(
          phase: CaptureFlowPhase.ready,
          recordingDuration: Duration.zero,
          clearError: true,
        ),
      );
      return;
    }
    if (_snapshot.phase != CaptureFlowPhase.recording) return;
    await _durationSubscription?.cancel();
    _durationSubscription = null;
    await _thoughtSegmentSubscription?.cancel();
    _thoughtSegmentSubscription = null;
    _enqueuedThoughtSegmentPaths.clear();
    _streamingThoughtSegmentsSaved = 0;
    await _deps.audio.cancelRecording();
    _deps.telemetry.recorderStopped(success: false);
    _emit(
      _snapshot.copyWith(
        phase: CaptureFlowPhase.ready,
        recordingDuration: Duration.zero,
        clearError: true,
      ),
    );
  }

  Future<void> stopVoiceCapture() async {
    if (_backgroundCaptureUi) {
      _backgroundCaptureUi = false;
      if (!_transition(CaptureFlowPhase.stopping)) return;
      if (_stopBackgroundCapture != null) {
        await _stopBackgroundCapture!();
      }
      _emit(
        _snapshot.copyWith(
          phase: CaptureFlowPhase.ready,
          recordingDuration: Duration.zero,
          clearError: true,
        ),
      );
      return;
    }
    if (_snapshot.phase != CaptureFlowPhase.recording) return;
    if (!_transition(CaptureFlowPhase.stopping)) return;
    await _durationSubscription?.cancel();
    _durationSubscription = null;
    await _thoughtSegmentSubscription?.cancel();
    _thoughtSegmentSubscription = null;

    try {
      final stopResult = await _deps.audio.stopRecording();
      _deps.telemetry.recorderStopped(success: true);

      for (final segment in stopResult.thoughtSegments) {
        await _enqueueThoughtSegment(segment);
      }

      if (_streamingThoughtSegmentsSaved > 0) {
        await _deps.recovery.clearPendingVoice();
        try {
          if (await stopResult.file.exists()) {
            await stopResult.file.delete();
          }
        } catch (_, stackTrace) { // ignore: silent_catch_audit — best-effort temp recording cleanup
          // Best-effort temp recording file cleanup after streaming segments saved.
        }
        _emit(
          _snapshot.copyWith(
            phase: CaptureFlowPhase.ready,
            hasLocalDraft: false,
            recordingDuration: Duration.zero,
            clearStage: true,
            clearError: true,
          ),
        );
        return;
      }

      await _deps.recovery.recordPendingVoice(
        audioPath: stopResult.file.path,
        durationSeconds: stopResult.durationSeconds,
      );
      _emit(
        _snapshot.copyWith(
          hasLocalDraft: true,
          stageLabel: 'Stopping…',
        ),
      );
      await _persistVoice(
        file: stopResult.file,
        durationSeconds: stopResult.durationSeconds,
      );
    } on RecordingException catch (e, stackTrace) {
      _deps.telemetry.recorderStopped(success: false);
      _failRecoverable(
        e.message,
        hasLocalDraft: false,
        hasLocalSave: false,
      );
    } catch (e, stackTrace) {
      CaptureFlowLog.unexpectedFailure(
        operation: 'stop_voice_capture',
        error: e,
        stackTrace: stackTrace,
      );
      _deps.telemetry.recorderStopped(success: false);
      _failRecoverable(
        VoiceCaptureCopy.saveFailed,
        hasLocalDraft: _snapshot.hasLocalDraft,
        hasLocalSave: _snapshot.hasLocalSave,
      );
    }
  }

  Future<void> saveTypedCapture(String transcript) async {
    if (_snapshot.isBusy || _snapshot.showsPostSave) return;
    if (!_transition(CaptureFlowPhase.savingLocal)) return;
    _emit(
      _snapshot.copyWith(
        inputMode: CaptureInputMode.typed,
        stageLabel: 'Saving…',
        clearError: true,
      ),
    );
    if (_snapshot.isAttachMode) {
      await _persistAttach(transcript);
    } else {
      await _persistTyped(transcript);
    }
  }

  /// Updates receipt after the user corrected transcript text locally.
  Future<void> applyTranscriptCorrection(JournalEntry corrected) async {
    _emit(
      _snapshot.copyWith(
        savedEntry: corrected,
        hasLocalSave: true,
        recoveryKind: CaptureRecoveryKind.none,
        clearError: true,
      ),
    );
  }

  /// Completes post-save after pending-transcript recovery or typed attach.
  Future<void> completeReturningUserSave(CapturePipelineResult result) async {
    _completeSave(result, incrementEntryCount: !result.attachedTypedTextToVoiceEntry);
  }

  Future<void> attachTypedToSavedEntry(String transcript) async {
    final entry = _snapshot.savedEntry;
    if (entry == null) return;
    if (!_transition(CaptureFlowPhase.savingLocal)) return;
    await _persistAttach(transcript, entry: entry);
  }

  Future<void> retryRemoteProcessing() async {
    final entry = _snapshot.savedEntry;
    if (entry == null) return;

    final transcriptionOk = await _deps.transcription.transcriptionAllowed();
    final reflectionOk = await _deps.reflection.reflectionAllowed();
    if (!transcriptionOk && !reflectionOk) {
      _emit(
        _snapshot.copyWith(
          errorMessage: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
        ),
      );
      return;
    }

    if (!_transition(CaptureFlowPhase.processingRemote)) return;

    _deps.telemetry.remoteProcessingStarted(kind: 'retry');
    _emit(
      _snapshot.copyWith(
        stageLabel: VoiceCaptureCopy.analysisUnavailableNote,
        clearError: true,
      ),
    );

    try {
      final outcome = await _deps.moments.retryRemoteForEntry(
        entry: entry,
      );
      outcome.match(
        (_) {
          _deps.telemetry.remoteProcessingCompleted(success: false, kind: 'retry');
          _emit(
            _snapshot.copyWith(
              phase: CaptureFlowPhase.savedLocal,
              hasLocalSave: true,
              errorMessage: VoiceCaptureCopy.analysisUnavailableNote,
            ),
          );
        },
        (result) async {
          _deps.telemetry.remoteProcessingCompleted(
            success: result.analysisSucceeded,
            kind: 'retry',
          );
          await _deps.recovery.clearPendingVoice();
          _completeSave(result, incrementEntryCount: false);
        },
      );
    } catch (e, stackTrace) {
      CaptureFlowLog.unexpectedFailure(
        operation: 'retry_remote_processing',
        error: e,
        stackTrace: stackTrace,
      );
      _deps.telemetry.remoteProcessingCompleted(success: false, kind: 'retry');
      _emit(
        _snapshot.copyWith(
          phase: CaptureFlowPhase.savedLocal,
          hasLocalSave: true,
          errorMessage: VoiceCaptureCopy.analysisUnavailableNote,
        ),
      );
    }
  }

  Future<void> resetToReady() async {
    await _durationSubscription?.cancel();
    _durationSubscription = null;
    _emit(
      CaptureFlowSnapshot(
        phase: CaptureFlowPhase.ready,
        inputMode: _snapshot.inputMode,
        entryCount: _snapshot.entryCount,
        routineKind: _snapshot.routineKind,
      ),
    );
    if (_attachToEntryId == null) {
      await _loadRoutinePrompt();
    }
  }

  Future<void> recoverPendingCapture() async {
    await _recoverPendingIfNeeded();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_durationSubscription?.cancel());
    unawaited(_pipelineStageSubscription?.cancel());
    unawaited(_thoughtSegmentSubscription?.cancel());
    super.dispose();
  }

  Future<void> _enqueueThoughtSegment(VoiceThoughtSegment segment) async {
    if (_enqueuedThoughtSegmentPaths.contains(segment.filePath)) return;
    _enqueuedThoughtSegmentPaths.add(segment.filePath);

    final file = File(segment.filePath);
    if (!await file.exists()) return;
    if (await file.length() < VoiceCaptureQuality.minAudioBytes) {
      try {
        await file.delete();
      } catch (_, stackTrace) { // ignore: silent_catch_audit — best-effort undersized segment delete
        // Best-effort delete for undersized streaming segment files.
      }
      return;
    }

    final durationSeconds =
        (segment.durationMs / 1000).ceil().clamp(1, 999999);
    try {
      final outcome = await _deps.moments.saveVoiceCapture(
        audioFile: file,
        durationSeconds: durationSeconds,
      );
      outcome.match(
        (_) {},
        (_) {
          _streamingThoughtSegmentsSaved += 1;
        },
      );
    } on Object {
      _enqueuedThoughtSegmentPaths.remove(segment.filePath);
    }
  }

  Future<void> _persistVoice({
    required File file,
    required int durationSeconds,
  }) async {
    if (!_transition(CaptureFlowPhase.savingLocal)) return;
    _deps.telemetry.localSaveStarted(kind: 'voice');
    _emit(_snapshot.copyWith(stageLabel: 'Saving…'));

    try {
      final exists = await file.exists();
      final bytes = exists ? await file.length() : 0;
      if (!exists || bytes < VoiceCaptureQuality.minAudioBytes) {
        if (exists) await file.delete();
        await _deps.recovery.clearPendingVoice();
        throw CapturePipelineFailure(VoiceCaptureCopy.notEnoughAudio);
      }

      // Measured before the save so the answer describes this device and this
      // permission rather than whatever the upload happened to do. Nothing here
      // touches the network.
      final capability = await _evaluateTranscriptionCapability();

      final transcriptionAllowed =
          await _deps.transcription.transcriptionAllowed();
      final reflectionAllowed = await _deps.reflection.reflectionAllowed();
      if (transcriptionAllowed || reflectionAllowed) {
        _deps.telemetry.remoteProcessingStarted(kind: 'voice');
        if (_transition(CaptureFlowPhase.processingRemote)) {
          _emit(_snapshot.copyWith(stageLabel: 'Transcribing…'));
        }
      }

      final outcome = await _deps.moments.saveVoiceCapture(
        audioFile: file,
        durationSeconds: durationSeconds,
      );

      outcome.match(
        (failure) {
          if (failure.message == VoiceCaptureCopy.notEnoughAudio) {
            _emit(
              _snapshot.copyWith(
                phase: CaptureFlowPhase.ready,
                hasLocalDraft: false,
                errorMessage: failure.message,
                clearStage: true,
              ),
            );
            return;
          }
          _failRecoverable(
            failure.message,
            hasLocalDraft: failure.savedDraft,
            hasLocalSave: failure.entry != null,
            entry: failure.entry,
          );
        },
        (result) {
          _deps.telemetry.localSaveCompleted(success: result.localSaved, kind: 'voice');
          _deps.telemetry.remoteProcessingCompleted(
            success: result.analysisSucceeded,
            kind: 'voice',
          );
          unawaited(_deps.recovery.clearPendingVoice());
          _completeSave(result);
          // After the save, deliberately. The recording keeps its audio either
          // way, so the question is never the price of storing it.
          if (capability == TranscriptionCapabilityOutcome.askOnce) {
            _emit(_snapshot.copyWith(transcriptionChoiceRequired: true));
          } else if (capability ==
              TranscriptionCapabilityOutcome.askSpeechLanguage) {
            _emit(_snapshot.copyWith(speechLocaleChoiceRequired: true));
          }
        },
      );
    } catch (e, stackTrace) {
      CaptureFlowLog.unexpectedFailure(
        operation: 'persist_voice',
        error: e,
        stackTrace: stackTrace,
      );
      _failRecoverable(
        VoiceCaptureCopy.saveFailed,
        hasLocalDraft: true,
        hasLocalSave: false,
      );
    }
  }

  /// Whether this device can transcribe at all, failing quiet on error.
  ///
  /// A capability probe that throws is not evidence of a capability gap, so it
  /// resolves to [TranscriptionCapabilityOutcome.proceed]: a privacy prompt
  /// raised by a broken probe would be a prompt the customer cannot act on
  /// honestly.
  Future<TranscriptionCapabilityOutcome>
      _evaluateTranscriptionCapability() async {
    try {
      return await _deps.transcriptionCapability.evaluate();
    } on Object {
      // ignore: silent_catch_audit — see above.
      return TranscriptionCapabilityOutcome.proceed;
    }
  }

  /// Records the customer's answer to the transcription prompt, permanently.
  ///
  /// [allowRemote] false is a real answer, not a dismissal: it is stored, and
  /// [TranscriptionCapabilityPolicy] stops asking.
  Future<void> resolveTranscriptionChoice({required bool allowRemote}) async {
    if (!_snapshot.transcriptionChoiceRequired) return;
    _emit(_snapshot.copyWith(transcriptionChoiceRequired: false));
    try {
      await _deps.transcriptionCapability.recordChoice(
        allowRemote: allowRemote,
      );
    } on Object catch (error, stackTrace) {
      CaptureFlowLog.unexpectedFailure(
        operation: 'resolve_transcription_choice',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Records which language the customer speaks, permanently.
  ///
  /// Takes a [ConfirmedSpeechLocale], so there is no overload of this that a
  /// caller could reach with a device setting. If the write fails the flag goes
  /// back up rather than staying down: an answer that did not persist has not
  /// been given, and silently proceeding would leave on-device recognition
  /// disabled with no way for the customer to find out why.
  Future<void> resolveSpeechLocale(ConfirmedSpeechLocale locale) async {
    if (!_snapshot.speechLocaleChoiceRequired) return;
    _emit(_snapshot.copyWith(speechLocaleChoiceRequired: false));
    try {
      await _deps.transcriptionCapability.recordSpeechLocale(locale);
    } on Object catch (error, stackTrace) {
      CaptureFlowLog.unexpectedFailure(
        operation: 'resolve_speech_locale',
        error: error,
        stackTrace: stackTrace,
      );
      _emit(_snapshot.copyWith(speechLocaleChoiceRequired: true));
    }
  }

  Future<void> _persistAttach(
    String transcript, {
    JournalEntry? entry,
  }) async {
    final target = entry ??
        (_snapshot.attachToEntryId != null
            ? await _deps.moments.loadEntry(_snapshot.attachToEntryId!)
            : _snapshot.savedEntry);
    if (target == null) {
      _failRecoverable(
        VoiceCaptureCopy.saveFailed,
        hasLocalDraft: false,
        hasLocalSave: false,
      );
      return;
    }

    _deps.telemetry.localSaveStarted(kind: 'typed_attach');
    try {
      final reflectionAllowed = await _deps.reflection.reflectionAllowed();
      if (reflectionAllowed) {
        _deps.telemetry.remoteProcessingStarted(kind: 'typed_attach');
        if (_transition(CaptureFlowPhase.processingRemote)) {
          _emit(_snapshot.copyWith(stageLabel: 'Analyzing…'));
        }
      }

      final outcome = await _deps.moments.attachTypedToVoiceEntry(
        entry: target,
        transcript: transcript,
      );

      outcome.match(
        (failure) => _failRecoverable(
          failure.message,
          hasLocalDraft: false,
          hasLocalSave: failure.entry != null,
          entry: failure.entry,
        ),
        (result) {
          _deps.telemetry.localSaveCompleted(
            success: result.localSaved,
            kind: 'typed_attach',
          );
          _deps.telemetry.remoteProcessingCompleted(
            success: result.analysisSucceeded,
            kind: 'typed_attach',
          );
          _completeSave(result, incrementEntryCount: false);
        },
      );
    } catch (e, stackTrace) {
      CaptureFlowLog.unexpectedFailure(
        operation: 'persist_attach',
        error: e,
        stackTrace: stackTrace,
      );
      _failRecoverable(
        VoiceCaptureCopy.saveFailed,
        hasLocalDraft: false,
        hasLocalSave: true,
        entry: target,
      );
    }
  }

  Future<void> _persistTyped(String transcript) async {
    _deps.telemetry.localSaveStarted(kind: 'typed');
    try {
      final reflectionAllowed = await _deps.consent.isGranted(
        RemoteProcessingPurpose.remoteReflection,
      );
      if (reflectionAllowed) {
        _deps.telemetry.remoteProcessingStarted(kind: 'typed');
        if (_transition(CaptureFlowPhase.processingRemote)) {
          _emit(_snapshot.copyWith(stageLabel: 'Analyzing…'));
        }
      }

      final outcome = await _deps.moments.saveTypedCapture(
        transcript: transcript,
      );

      outcome.match(
        (failure) => _failRecoverable(
          failure.message,
          hasLocalDraft: false,
          hasLocalSave: failure.entry != null,
          entry: failure.entry,
        ),
        (result) {
          _deps.telemetry.localSaveCompleted(success: result.localSaved, kind: 'typed');
          _deps.telemetry.remoteProcessingCompleted(
            success: result.analysisSucceeded,
            kind: 'typed',
          );
          _completeSave(result);
        },
      );
    } catch (e, stackTrace) {
      CaptureFlowLog.unexpectedFailure(
        operation: 'persist_typed',
        error: e,
        stackTrace: stackTrace,
      );
      _failRecoverable(
        VoiceCaptureCopy.saveFailed,
        hasLocalDraft: false,
        hasLocalSave: false,
      );
    }
  }

  void _completeSave(
    CapturePipelineResult result, {
    bool incrementEntryCount = true,
  }) {
    final phase = result.localSaved
        ? (result.analysisSucceeded
              ? CaptureFlowPhase.savedWithReflection
              : CaptureFlowPhase.savedLocal)
        : CaptureFlowPhase.recoverableFailure;

    if (!_transition(phase)) return;

    final count = incrementEntryCount
        ? _snapshot.entryCount + 1
        : _snapshot.entryCount;
    _emit(
      _snapshot.copyWith(
        phase: phase,
        savedEntry: result.entry,
        pipelineResult: result,
        entryCount: count,
        hasLocalSave: result.localSaved,
        hasLocalDraft: false,
        recoveryKind: CaptureRecoveryKind.none,
        clearError: true,
        clearStage: true,
      ),
    );
  }

  void _failRecoverable(
    String message, {
    required bool hasLocalDraft,
    required bool hasLocalSave,
    JournalEntry? entry,
  }) {
    _deps.telemetry.recoverableFailure(
      reason: message,
      hasLocalSave: hasLocalSave,
    );
    if (!_transition(CaptureFlowPhase.recoverableFailure)) return;
    _emit(
      _snapshot.copyWith(
        phase: CaptureFlowPhase.recoverableFailure,
        errorMessage: message,
        hasLocalDraft: hasLocalDraft,
        hasLocalSave: hasLocalSave,
        savedEntry: entry ?? _snapshot.savedEntry,
        clearStage: true,
      ),
    );
  }

  Future<void> _recoverPendingIfNeeded() async {
    final pending = await _deps.recovery.readPendingVoice();
    if (pending == null) return;
    final file = File(pending.audioPath);
    if (!await file.exists()) {
      await _deps.recovery.clearPendingVoice();
      return;
    }
    _emit(
      _snapshot.copyWith(
        phase: CaptureFlowPhase.recoverableFailure,
        hasLocalDraft: true,
        recoveryKind: CaptureRecoveryKind.interruptedVoice,
        errorMessage: VoiceCaptureCopy.saveFailed,
        stageLabel: 'Recovering interrupted capture…',
      ),
    );
    await _persistVoice(
      file: file,
      durationSeconds: pending.durationSeconds,
    );
  }

  void _onPipelineStage(PipelineStage stage) {
    final label = switch (stage) {
      PipelineStage.attesting => 'Uploading audio…',
      PipelineStage.transcribing => 'Transcribing…',
      PipelineStage.analyzing => 'Reviewing your moment…',
      PipelineStage.saving => 'Saving…',
      PipelineStage.done => 'Done',
    };
    _emit(_snapshot.copyWith(stageLabel: label));
  }

  bool _transition(CaptureFlowPhase to) {
    final from = _snapshot.phase;
    if (!CaptureFlowTransitionGuard.canTransition(from, to)) {
      _deps.telemetry.illegalTransition(from: from, to: to);
      return false;
    }
    if (from != to) {
      _emit(_snapshot.copyWith(phase: to));
    }
    return true;
  }

  void _emit(CaptureFlowSnapshot next) {
    if (_disposed) return;
    _snapshot = next;
    notifyListeners();
  }
}