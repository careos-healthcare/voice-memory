import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_dependencies.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_screen.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/routine/routine_anchor_model.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_capability_policy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _smallScreen = Size(360, 640);

class _FakeAudio implements AudioRecorderAdapter {
  final _duration = StreamController<int>.broadcast();

  @override
  Future<void> cancelRecording() async {}

  @override
  Stream<int> get durationSeconds => _duration.stream;

  @override
  Future<MicPermissionResolution> evaluatePermission() async =>
      MicPermissionResolution(
        phase: RecordingPhase.ready,
        state: MicrophonePermissionState.granted,
        hasRecorder: true,
      );

  @override
  Future<MicPermissionResolution> requestPermission() async =>
      evaluatePermission();

  @override
  bool get supportsPause => false;

  @override
  Future<void> pauseRecording() async {}

  @override
  Future<void> resumeRecording() async {}

  @override
  Stream<VadSegmentEvent>? get thoughtSegmentEvents => null;

  @override
  Future<void> startRecording({required bool permissionVerified}) async {
    _duration.add(1);
  }

  @override
  Future<AudioStopResult> stopRecording() async =>
      AudioStopResult(file: File('test_audio.m4a'), durationSeconds: 3);
}

class _FakeMoments implements LocalMomentRepository {
  final _pipelineStates = StreamController<PipelineState>.broadcast();

  @override
  Stream<PipelineState> get pipelineStates => _pipelineStates.stream;

  @override
  Future<CapturePipelineOutcome> attachTypedToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
  }) async => Left(CapturePipelineFailure('unused'));

  @override
  Future<JournalEntry?> loadEntry(String entryId) async => null;

  @override
  Future<int> entryCount() async => 0;

  @override
  Future<CapturePipelineOutcome> retryRemoteForEntry({
    required JournalEntry entry,
  }) async => Left(CapturePipelineFailure('unused'));

  @override
  Future<CapturePipelineOutcome> saveTypedCapture({
    required String transcript,
  }) async => Left(CapturePipelineFailure('unused'));

  @override
  Future<CapturePipelineOutcome> saveVoiceCapture({
    required File audioFile,
    required int durationSeconds,
  }) async => Left(CapturePipelineFailure('unused'));
}

class _FakeConsent implements RemoteConsentPolicy {
  @override
  Future<bool> isGranted(RemoteProcessingPurpose purpose) async => true;
}

class _FakeTranscription implements RemoteTranscriptionGateway {
  @override
  Future<bool> transcriptionAllowed() async => true;
}

class _FakeReflection implements RemoteReflectionGateway {
  @override
  Future<bool> reflectionAllowed() async => true;
}

class _FakeRecovery implements PendingCaptureRecoveryStore {
  @override
  Future<void> clearPendingVoice() async {}

  @override
  Future<PendingVoiceCapture?> readPendingVoice() async => null;

  @override
  Future<void> recordPendingVoice({
    required String audioPath,
    required int durationSeconds,
  }) async {}
}

class _FakeTranscriptCorrection implements TranscriptCorrectionPort {
  @override
  Future<JournalEntry> apply({
    required JournalEntry entry,
    required String correctedText,
  }) async => entry;
}

class _FakeRoutinePrompts implements RoutinePromptGateway {
  @override
  Future<RoutineJournalPrompt?> loadPrompt({
    required JournalRoutineKind routine,
    JournalEntry? latestEntry,
    List<JournalEntry>? archiveEntries,
  }) async => const RoutineJournalPrompt(
    routine: JournalRoutineKind.morning,
    primaryPrompt:
        'What did you say yes to before you had capacity, and what did '
        'that cost you later in the day when the next request arrived?',
    supportingPrompts: [
      'What did you agree to?',
      'What would you do differently next time?',
      'What felt like one thing too many?',
    ],
    contextChunks: [],
  );
}

class _FakeRoutineAnchors implements RoutineAnchorLoader {
  @override
  Future<RoutineAnchor?> loadLatest() async => null;
}

class _FakeTranscriptionCapability implements TranscriptionCapabilityPort {
  @override
  Future<TranscriptionCapabilityOutcome> evaluate() async =>
      TranscriptionCapabilityOutcome.proceed;

  @override
  Future<void> recordChoice({required bool allowRemote}) async {}

  @override
  Future<void> recordSpeechLocale(ConfirmedSpeechLocale locale) async {}
}

class _FakeTelemetry implements CaptureTelemetry {
  @override
  void illegalTransition({
    required CaptureFlowPhase from,
    required CaptureFlowPhase to,
  }) {}

  @override
  void localSaveCompleted({required bool success, required String kind}) {}

  @override
  void localSaveStarted({required String kind}) {}

  @override
  void permissionChecked({required String status}) {}

  @override
  void permissionRequested({required String status}) {}

  @override
  void recorderStarted({required bool success}) {}

  @override
  void recorderStopped({required bool success}) {}

  @override
  void recoverableFailure({
    required bool hasLocalSave,
    required String reason,
  }) {}

  @override
  void remoteProcessingCompleted({
    required bool success,
    required String kind,
  }) {}

  @override
  void remoteProcessingStarted({required String kind}) {}
}

CaptureFlowDependencies _deps() {
  return CaptureFlowDependencies(
    audio: _FakeAudio(),
    moments: _FakeMoments(),
    consent: _FakeConsent(),
    transcription: _FakeTranscription(),
    reflection: _FakeReflection(),
    recovery: _FakeRecovery(),
    telemetry: _FakeTelemetry(),
    transcriptCorrection: _FakeTranscriptCorrection(),
    routinePrompts: _FakeRoutinePrompts(),
    routineAnchors: _FakeRoutineAnchors(),
    transcriptionCapability: _FakeTranscriptionCapability(),
  );
}

Future<List<FlutterErrorDetails>> _pumpCaptureScreen(
  WidgetTester tester, {
  required double scale,
  CaptureInputMode inputMode = CaptureInputMode.voice,
}) async {
  final flutterErrors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    flutterErrors.add(details);
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);

  await tester.binding.setSurfaceSize(_smallScreen);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: CaptureScreen(
          initialInputMode: inputMode,
          routineKindOverride: JournalRoutineKind.morning,
          dependencies: _deps(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return flutterErrors;
}

void main() {
  group('CaptureScreen dynamic type', () {
    testWidgets(
      'ready voice with routine prompt stays usable at 200% text scale',
      (tester) async {
        final errors = await _pumpCaptureScreen(tester, scale: 2);
        expect(find.byType(CaptureScreen), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsWidgets);
        expect(find.byKey(const Key('capture_start_voice')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('capture_start_voice')));
        expect(
          errors,
          isEmpty,
          reason:
              'CaptureScreen ready overflowed at 200% text scale: '
              '${errors.map((d) => d.exceptionAsString()).join('; ')}',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ready typed with routine prompt stays usable at 200% text scale',
      (tester) async {
        final errors = await _pumpCaptureScreen(
          tester,
          scale: 2,
          inputMode: CaptureInputMode.typed,
        );
        expect(find.byKey(const Key('capture_typed_field')), findsOneWidget);
        expect(find.byKey(const Key('capture_save_typed')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('capture_save_typed')));
        expect(
          errors,
          isEmpty,
          reason:
              'CaptureScreen typed ready overflowed at 200% text scale: '
              '${errors.map((d) => d.exceptionAsString()).join('; ')}',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('recording stays usable at 200% text scale', (tester) async {
      final errors = await _pumpCaptureScreen(tester, scale: 2);
      await tester.ensureVisible(find.byKey(const Key('capture_start_voice')));
      await tester.tap(find.byKey(const Key('capture_start_voice')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('capture_recording_timer')), findsOneWidget);
      expect(find.byKey(const Key('capture_stop_voice')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('capture_stop_voice')));
      expect(
        errors,
        isEmpty,
        reason:
            'CaptureScreen recording overflowed at 200% text scale: '
            '${errors.map((d) => d.exceptionAsString()).join('; ')}',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
