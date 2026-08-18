import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/audio/recording_types.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_controller.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_dependencies.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_transition_guard.dart';
import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';

/// Production path under test (strangler ON):
/// permission → record/stop OR typed save → local persist → optional remote → receipt.
class _FakeAudio implements AudioRecorderAdapter {
  MicPermissionResolution permission = MicPermissionResolution(
    phase: RecordingPhase.ready,
    state: MicrophonePermissionState.granted,
    hasRecorder: true,
  );
  bool startShouldFail = false;
  File? lastFile;
  final _duration = StreamController<int>.broadcast();

  @override
  Future<void> cancelRecording() async {}

  @override
  Stream<int> get durationSeconds => _duration.stream;

  @override
  Future<MicPermissionResolution> evaluatePermission() async => permission;

  @override
  Future<MicPermissionResolution> requestPermission() async => permission;

  @override
  bool get supportsPause => false;

  @override
  Future<void> pauseRecording() async {}

  @override
  Future<void> resumeRecording() async {}

  @override
  Future<void> startRecording({required bool permissionVerified}) async {
    if (startShouldFail) throw RecordingException('start failed');
    _duration.add(1);
  }

  @override
  Future<AudioStopResult> stopRecording() async {
    final file = lastFile ?? File('test_audio.m4a');
    return AudioStopResult(file: file, durationSeconds: 3);
  }
}

class _FakeMoments implements LocalMomentRepository {
  CapturePipelineResult? voiceResult;
  CapturePipelineResult? typedResult;
  CapturePipelineResult? attachResult;
  Object? voiceError;
  int count = 0;
  int retryCalls = 0;
  int attachCalls = 0;
  final entries = <String, JournalEntry>{};
  final _pipelineStates = StreamController<PipelineState>.broadcast();

  @override
  Stream<PipelineState> get pipelineStates => _pipelineStates.stream;

  @override
  Future<CapturePipelineOutcome> attachTypedToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
  }) async {
    attachCalls++;
    if (attachResult != null) return Right(attachResult!);
    return Left(CapturePipelineFailure('attach failed'));
  }

  @override
  Future<JournalEntry?> loadEntry(String entryId) async => entries[entryId];

  @override
  Future<int> entryCount() async => count;

  @override
  Future<CapturePipelineOutcome> retryRemoteForEntry({
    required JournalEntry entry,
  }) async {
    retryCalls++;
    return Right(voiceResult!);
  }

  @override
  Future<CapturePipelineOutcome> saveTypedCapture({
    required String transcript,
  }) async {
    if (typedResult != null) return Right(typedResult!);
    return Left(CapturePipelineFailure('typed failed'));
  }

  @override
  Future<CapturePipelineOutcome> saveVoiceCapture({
    required File audioFile,
    required int durationSeconds,
  }) async {
    if (voiceError != null) throw voiceError!;
    if (voiceResult != null) return Right(voiceResult!);
    return Left(CapturePipelineFailure('voice failed'));
  }
}

class _FakeConsent implements RemoteConsentPolicy {
  bool granted = true;

  @override
  Future<bool> isGranted(RemoteProcessingPurpose purpose) async => granted;
}

class _FakeTranscription implements RemoteTranscriptionGateway {
  _FakeTranscription(this._consent);
  final _FakeConsent _consent;

  @override
  Future<bool> transcriptionAllowed() =>
      _consent.isGranted(RemoteProcessingPurpose.remoteTranscription);
}

class _FakeReflection implements RemoteReflectionGateway {
  _FakeReflection(this._consent);
  final _FakeConsent _consent;

  @override
  Future<bool> reflectionAllowed() =>
      _consent.isGranted(RemoteProcessingPurpose.remoteReflection);
}

class _FakeRecovery implements PendingCaptureRecoveryStore {
  PendingVoiceCapture? pending;

  @override
  Future<void> clearPendingVoice() async {
    pending = null;
  }

  @override
  Future<PendingVoiceCapture?> readPendingVoice() async => pending;

  @override
  Future<void> recordPendingVoice({
    required String audioPath,
    required int durationSeconds,
  }) async {
    pending = PendingVoiceCapture(
      audioPath: audioPath,
      durationSeconds: durationSeconds,
    );
  }
}

class _FakeTranscriptCorrection implements TranscriptCorrectionPort {
  @override
  Future<JournalEntry> apply({
    required JournalEntry entry,
    required String correctedText,
  }) async {
    return entry.copyWith(transcript: correctedText);
  }
}

class _FakeTelemetry implements CaptureTelemetry {
  final transitions = <String>[];
  final events = <String>[];

  @override
  void illegalTransition({
    required CaptureFlowPhase from,
    required CaptureFlowPhase to,
  }) {
    transitions.add('${from.name}->${to.name}');
  }

  @override
  void localSaveCompleted({required bool success, required String kind}) {
    events.add('local_save_$kind:$success');
  }

  @override
  void localSaveStarted({required String kind}) => events.add('local_start_$kind');

  @override
  void permissionChecked({required String status}) =>
      events.add('perm_check:$status');

  @override
  void permissionRequested({required String status}) =>
      events.add('perm_request:$status');

  @override
  void recorderStarted({required bool success}) =>
      events.add('recorder_start:$success');

  @override
  void recorderStopped({required bool success}) =>
      events.add('recorder_stop:$success');

  @override
  void recoverableFailure({required bool hasLocalSave, required String reason}) {
    events.add('recoverable:$reason:$hasLocalSave');
  }

  @override
  void remoteProcessingCompleted({required bool success, required String kind}) {
    events.add('remote_done_$kind:$success');
  }

  @override
  void remoteProcessingStarted({required String kind}) =>
      events.add('remote_start_$kind');
}

JournalEntry _entry({String id = 'e1'}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 8, 12),
  transcript: 'I said yes before checking my calendar.',
  durationSeconds: 3,
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

CapturePipelineResult _result({bool analysis = true}) => CapturePipelineResult(
  entry: _entry(),
  localSaved: true,
  syncSucceeded: analysis,
  analysisSucceeded: analysis,
);

CaptureFlowController _controller({
  _FakeAudio? audio,
  _FakeMoments? moments,
  _FakeConsent? consent,
  _FakeRecovery? recovery,
  _FakeTelemetry? telemetry,
  String? attachToEntryId,
}) {
  final fakeConsent = consent ?? _FakeConsent();
  return CaptureFlowController(
    CaptureFlowDependencies(
      audio: audio ?? _FakeAudio(),
      moments: moments ?? _FakeMoments(),
      consent: fakeConsent,
      transcription: _FakeTranscription(fakeConsent),
      reflection: _FakeReflection(fakeConsent),
      recovery: recovery ?? _FakeRecovery(),
      telemetry: telemetry ?? _FakeTelemetry(),
      transcriptCorrection: _FakeTranscriptCorrection(),
    ),
    attachToEntryId: attachToEntryId,
  );
}

void main() {
  group('CaptureFlowTransitionGuard', () {
    test('exhaustive legal transitions for fresh-user path', () {
      expect(
        CaptureFlowTransitionGuard.canTransition(
          CaptureFlowPhase.ready,
          CaptureFlowPhase.requestingPermission,
        ),
        isTrue,
      );
      expect(
        CaptureFlowTransitionGuard.canTransition(
          CaptureFlowPhase.recording,
          CaptureFlowPhase.ready,
        ),
        isTrue,
      );
      expect(
        CaptureFlowTransitionGuard.canTransition(
          CaptureFlowPhase.ready,
          CaptureFlowPhase.processingRemote,
        ),
        isFalse,
      );
    });
  });

  group('CaptureFlowController characterization', () {
    late File tempAudioFile;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('capture_flow_test_');
      tempAudioFile = File('${dir.path}/sample.m4a');
      await tempAudioFile.writeAsBytes(List.filled(5000, 1));
    });

    test('permission denied stays on ready without recording', () async {
      final audio = _FakeAudio()
        ..permission = MicPermissionResolution(
          phase: RecordingPhase.permissionDenied,
          state: MicrophonePermissionState.deniedCanAskAgain,
          hasRecorder: true,
        );
      final controller = _controller(audio: audio);
      await controller.startVoiceCapture();
      expect(controller.snapshot.phase, CaptureFlowPhase.ready);
      expect(controller.snapshot.permissionBlocked, isTrue);
    });

    test('voice capture saves locally when remote declines', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()
        ..voiceResult = _result(analysis: false)
        ..count = 0;
      final consent = _FakeConsent()..granted = false;
      final controller = _controller(audio: audio, moments: moments, consent: consent);
      await controller.startVoiceCapture();
      expect(controller.snapshot.phase, CaptureFlowPhase.recording);
      await controller.stopVoiceCapture();
      expect(controller.snapshot.phase, CaptureFlowPhase.savedLocal);
      expect(controller.snapshot.hasLocalSave, isTrue);
    });

    test('voice capture reaches savedWithReflection on remote success', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: true);
      final controller = _controller(audio: audio, moments: moments);
      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();
      expect(controller.snapshot.phase, CaptureFlowPhase.savedWithReflection);
      expect(controller.snapshot.entryCount, 1);
    });

    test('typed capture saves locally without remote consent', () async {
      final moments = _FakeMoments()
        ..typedResult = CapturePipelineResult(
          entry: _entry(id: 'typed-1'),
          localSaved: true,
          syncSucceeded: false,
          analysisSucceeded: false,
          syncNote: VoiceCaptureCopy.remoteProcessingConsentPausedNote,
        );
      final consent = _FakeConsent()..granted = false;
      final controller = _controller(moments: moments, consent: consent);
      await controller.saveTypedCapture('Today I noticed pressure at work.');
      expect(controller.snapshot.phase, CaptureFlowPhase.savedLocal);
      expect(controller.snapshot.hasLocalSave, isTrue);
    });

    test('cancellation returns to ready without save', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final controller = _controller(audio: audio);
      await controller.startVoiceCapture();
      await controller.cancelVoiceCapture();
      expect(controller.snapshot.phase, CaptureFlowPhase.ready);
    });

    test('remote retry blocked when consent withdrawn', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: true);
      final consent = _FakeConsent()..granted = true;
      final controller = _controller(
        audio: audio,
        moments: moments,
        consent: consent,
      );
      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();
      consent.granted = false;
      await controller.retryRemoteProcessing();
      expect(moments.retryCalls, 0);
      expect(controller.snapshot.phase, CaptureFlowPhase.savedWithReflection);
    });

    test('local save survives remote pipeline failure', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()
        ..voiceResult = CapturePipelineResult(
          entry: _entry(),
          localSaved: true,
          syncSucceeded: false,
          analysisSucceeded: false,
          syncNote: VoiceCaptureCopy.analysisUnavailableNote,
        );
      final controller = _controller(audio: audio, moments: moments);
      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();
      expect(controller.snapshot.hasLocalSave, isTrue);
      expect(controller.snapshot.phase, CaptureFlowPhase.savedLocal);
    });

    test('interrupted capture recovery completes pending save', () async {
      final tempDir = await Directory.systemTemp.createTemp('capture_flow_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final audioFile = File('${tempDir.path}/pending.m4a');
      await audioFile.writeAsBytes(List.filled(5000, 1));

      final recovery = _FakeRecovery()
        ..pending = PendingVoiceCapture(
          audioPath: audioFile.path,
          durationSeconds: 4,
        );
      final moments = _FakeMoments()..voiceResult = _result();
      final audio = _FakeAudio()..lastFile = audioFile;
      final controller = _controller(
        audio: audio,
        moments: moments,
        recovery: recovery,
      );
      await controller.initialize();
      expect(controller.snapshot.phase, CaptureFlowPhase.savedWithReflection);
      expect(recovery.pending, isNull);
    });

    test('typed attach to voice entry does not increment entry count', () async {
      final entry = _entry(id: 'voice-attach');
      final moments = _FakeMoments()
        ..count = 2
        ..entries['voice-attach'] = entry
        ..attachResult = CapturePipelineResult(
          entry: entry,
          localSaved: true,
          syncSucceeded: true,
          analysisSucceeded: true,
          attachedTypedTextToVoiceEntry: true,
        );
      final controller = _controller(
        moments: moments,
        attachToEntryId: 'voice-attach',
      );
      await controller.initialize();
      await controller.saveTypedCapture('What I meant was no.');
      expect(moments.attachCalls, 1);
      expect(controller.snapshot.entryCount, 2);
      expect(controller.snapshot.phase, CaptureFlowPhase.savedWithReflection);
    });

    test('transcript correction updates receipt without new save', () async {
      final moments = _FakeMoments()
        ..typedResult = _result(analysis: true);
      final controller = _controller(moments: moments);
      await controller.saveTypedCapture('Original words.');
      final corrected = _entry().copyWith(transcript: 'Corrected words.');
      await controller.applyTranscriptCorrection(corrected);
      expect(controller.snapshot.savedEntry?.transcript, 'Corrected words.');
      expect(controller.snapshot.recoveryKind, CaptureRecoveryKind.none);
    });

    test('returning-user pending recovery completes post-save', () async {
      final moments = _FakeMoments()
        ..typedResult = _result(analysis: false);
      final controller = _controller(moments: moments);
      await controller.saveTypedCapture('Pending voice moment.');
      final recoveryResult = CapturePipelineResult(
        entry: _entry(),
        localSaved: true,
        syncSucceeded: true,
        analysisSucceeded: true,
        attachedTypedTextToVoiceEntry: true,
      );
      await controller.completeReturningUserSave(recoveryResult);
      expect(controller.snapshot.phase, CaptureFlowPhase.savedWithReflection);
      expect(controller.snapshot.entryCount, 1);
    });
  });
}
