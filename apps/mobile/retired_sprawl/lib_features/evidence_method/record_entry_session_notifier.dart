import 'dart:io';

import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/evidence_method/evidence_insight_client.dart';
import 'package:archiveme_mobile/features/evidence_method/record_entry_capture_service.dart';
import 'package:archiveme_mobile/features/evidence_method/record_entry_session_state.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_lifecycle_policy.dart';
import 'package:archiveme_mobile/features/onboarding/brain_dump_upload_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecordEntrySessionNotifier extends Notifier<RecordEntrySessionState> {
  late final RecordEntryCaptureService _captureService;
  late final EvidenceInsightClient _insightClient;

  @override
  RecordEntrySessionState build() {
    _captureService = RecordEntryCaptureService();
    _insightClient = EvidenceInsightClient(AppServices.instance.httpTransport);
    ref.onDispose(_captureService.dispose);
    return const RecordEntrySessionState();
  }

  void setCaptureScreenAttached(bool attached) {
    state = state.copyWith(captureScreenAttached: attached);
  }

  Future<void> onHoldStarted() async {
    if (state.isActiveCapture || state.isProcessing) {
      return;
    }

    state = state.copyWith(
      phase: RecordEntryPhase.connecting,
      clearInsight: true,
      clearTranscript: true,
      clearError: true,
      clearSavedEncryptedAudioPath: true,
    );

    try {
      await _captureService.beginHold();
      state = state.copyWith(phase: RecordEntryPhase.recording);
    } catch (error, stackTrace) {
      await _captureService.cancel();
      _fail(error);
    }
  }

  Future<void> onHoldEnded() async {
    if (state.isBrainDump) {
      await finishBrainDump();
      return;
    }
    if (state.phase != RecordEntryPhase.recording &&
        state.phase != RecordEntryPhase.backgroundPaused) {
      return;
    }
    state = state.copyWith(phase: RecordEntryPhase.processing);
    await _completeCapture(generateInsight: true);
  }

  Future<void> startBrainDump() async {
    if (state.isActiveCapture || state.isProcessing) {
      return;
    }

    state = state.copyWith(
      isBrainDump: true,
      elapsedSeconds: 0,
      promptIndex: 0,
      phase: RecordEntryPhase.connecting,
      clearInsight: true,
      clearTranscript: true,
      clearError: true,
      clearSavedEncryptedAudioPath: true,
    );

    try {
      await _captureService.beginHold();
      state = state.copyWith(phase: RecordEntryPhase.recording);
    } catch (error, stackTrace) {
      await _captureService.cancel();
      _fail(error);
    }
  }

  Future<void> finishBrainDump() async {
    if (state.phase != RecordEntryPhase.recording &&
        state.phase != RecordEntryPhase.backgroundPaused) {
      return;
    }

    state = state.copyWith(phase: RecordEntryPhase.generatingInsight);
    await _completeCapture(generateInsight: true, uploadEncryptedAudio: true);
  }

  void updateBrainDumpElapsed(int elapsedSeconds) {
    if (!state.isBrainDump) return;
    state = state.copyWith(
      elapsedSeconds: elapsedSeconds.clamp(
        0,
        RecordEntrySessionState.brainDumpMaxSeconds,
      ),
    );
  }

  void rotateBrainDumpPrompt(int promptIndex) {
    if (!state.isBrainDump) return;
    state = state.copyWith(promptIndex: promptIndex);
  }

  Future<void> _completeCapture({
    required bool generateInsight,
    bool uploadEncryptedAudio = false,
  }) async {
    if (state.phase != RecordEntryPhase.recording &&
        state.phase != RecordEntryPhase.backgroundPaused &&
        state.phase != RecordEntryPhase.generatingInsight) {
      state = state.copyWith(phase: RecordEntryPhase.processing);
    }

    try {
      final capture = await _captureService.endHold();
      state = state.copyWith(transcript: capture.transcript);

      if (uploadEncryptedAudio && capture.encryptedAudioPath != null) {
        final uploadService = BrainDumpUploadService(
          AppServices.instance.httpTransport,
        );
        await uploadService.uploadEncryptedBrainDump(
          encryptedAudio: File(capture.encryptedAudioPath!),
          entryId: capture.entryId,
          durationSeconds: state.elapsedSeconds.clamp(1, RecordEntrySessionState.brainDumpMaxSeconds),
        );
      }

      if (generateInsight) {
        final settings = await AppServices.instance.userSettings.load();
        final lens = settings.resolvedLens;
        final insight = await _insightClient.generateEvidenceBackedInsight(
          transcript: capture.transcript,
          entryId: capture.entryId,
          activeLens: lens.isThematic ? lens.wireValue : null,
        );
        state = state.copyWith(
          insight: insight,
          phase: RecordEntryPhase.complete,
        );
      } else {
        state = state.copyWith(phase: RecordEntryPhase.complete);
      }
    } catch (error, stackTrace) {
      await _captureService.cancel();
      _fail(error);
    }
  }

  Future<void> onHoldCanceled() async {
    if (!state.isActiveCapture) {
      return;
    }
    await _captureService.cancel();
    state = state.copyWith(
      phase: RecordEntryPhase.idle,
      isBrainDump: false,
      clearError: true,
      clearSavedEncryptedAudioPath: true,
    );
  }

  Future<void> handleAppLifecycle(AppLifecycleState lifecycle) async {
    if (LiveVoiceLifecyclePolicy.shouldPauseCapture(lifecycle)) {
      if (state.phase == RecordEntryPhase.recording) {
        await _pauseForBackground();
      }
      return;
    }

    if (lifecycle == AppLifecycleState.resumed &&
        state.phase == RecordEntryPhase.backgroundPaused) {
      await _resumeAfterBackground();
    }
  }

  Future<void> _pauseForBackground() async {
    try {
      final encryptedPath = await _captureService.pauseForBackground();
      state = state.copyWith(
        phase: RecordEntryPhase.backgroundPaused,
        savedEncryptedAudioPath: encryptedPath?.path,
      );
    } catch (error, stackTrace) {
      _fail(error);
    }
  }

  Future<void> _resumeAfterBackground() async {
    try {
      await _captureService.resumeAfterBackground();
      state = state.copyWith(phase: RecordEntryPhase.recording);
    } catch (error, stackTrace) {
      _fail(error);
    }
  }

  void reset() {
    final attached = state.captureScreenAttached;
    state = RecordEntrySessionState(captureScreenAttached: attached);
  }

  void _fail(Object error) {
    state = state.copyWith(
      phase: RecordEntryPhase.error,
      errorMessage: error.toString().replaceFirst('Exception: ', ''),
    );
  }
}