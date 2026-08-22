import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/audio/recording_types.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_controller.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_dependencies.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_transition_guard.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/routine/routine_anchor_model.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_capability_policy.dart';
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
  Stream<VadSegmentEvent>? get thoughtSegmentEvents => null;

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

class _FakeRoutinePrompts implements RoutinePromptGateway {
  RoutineJournalPrompt? nextPrompt;

  @override
  Future<RoutineJournalPrompt?> loadPrompt({
    required JournalRoutineKind routine,
    JournalEntry? latestEntry,
    List<JournalEntry>? archiveEntries,
  }) async =>
      nextPrompt;
}

class _FakeRoutineAnchors implements RoutineAnchorLoader {
  RoutineAnchor? anchor;

  @override
  Future<RoutineAnchor?> loadLatest() async => anchor;
}

/// Default: something can transcribe, so no prompt is raised.
class _FakeTranscriptionCapability implements TranscriptionCapabilityPort {
  TranscriptionCapabilityOutcome outcome =
      TranscriptionCapabilityOutcome.proceed;
  bool shouldThrow = false;
  bool recordShouldThrow = false;
  bool recordLocaleShouldThrow = false;
  final recordedChoices = <bool>[];
  final recordedLocales = <ConfirmedSpeechLocale>[];

  @override
  Future<TranscriptionCapabilityOutcome> evaluate() async {
    if (shouldThrow) throw StateError('capability probe failed');
    return outcome;
  }

  @override
  Future<void> recordChoice({required bool allowRemote}) async {
    if (recordShouldThrow) throw StateError('choice store failed');
    recordedChoices.add(allowRemote);
  }

  @override
  Future<void> recordSpeechLocale(ConfirmedSpeechLocale locale) async {
    if (recordLocaleShouldThrow) throw StateError('locale store failed');
    recordedLocales.add(locale);
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
  _FakeRoutinePrompts? routinePrompts,
  _FakeTranscriptionCapability? transcriptionCapability,
  String? attachToEntryId,
  JournalRoutineKind? routineKindOverride,
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
      routinePrompts: routinePrompts ?? _FakeRoutinePrompts(),
      routineAnchors: _FakeRoutineAnchors(),
      transcriptionCapability:
          transcriptionCapability ?? _FakeTranscriptionCapability(),
    ),
    attachToEntryId: attachToEntryId,
    routineKindOverride: routineKindOverride,
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

    test('loads routine prompt on initialize when not attaching', () async {
      final routinePrompts = _FakeRoutinePrompts()
        ..nextPrompt = const RoutineJournalPrompt(
          routine: JournalRoutineKind.morning,
          primaryPrompt: 'What feels honest this morning?',
          supportingPrompts: ['Name one concrete moment'],
          contextChunks: [],
        );
      final controller = _controller(
        routinePrompts: routinePrompts,
        routineKindOverride: JournalRoutineKind.morning,
      );
      await controller.initialize();
      expect(
        controller.snapshot.routinePrompt?.primaryPrompt,
        'What feels honest this morning?',
      );
      expect(controller.snapshot.showsRoutinePrompt, isTrue);
      controller.dismissRoutinePrompt();
      expect(controller.snapshot.showsRoutinePrompt, isFalse);
    });

    test('skips routine prompt load in attach mode', () async {
      final routinePrompts = _FakeRoutinePrompts()
        ..nextPrompt = const RoutineJournalPrompt(
          routine: JournalRoutineKind.evening,
          primaryPrompt: 'Evening prompt',
          supportingPrompts: [],
          contextChunks: [],
        );
      final controller = _controller(
        routinePrompts: routinePrompts,
        attachToEntryId: 'voice-attach',
      );
      await controller.initialize();
      expect(controller.snapshot.routinePrompt, isNull);
    });
  });

  group('transcription capability gap', () {
    late File tempAudioFile;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('capture_flow_stt_');
      tempAudioFile = File('${dir.path}/sample.m4a');
      await tempAudioFile.writeAsBytes(List.filled(5000, 1));
    });

    test('asks after the save when this device cannot transcribe', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.askOnce;
      final controller = _controller(
        audio: audio,
        moments: moments,
        consent: _FakeConsent()..granted = false,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();

      expect(controller.snapshot.transcriptionChoiceRequired, isTrue);
      // The recording is already saved. The question is about text, not about
      // whether the moment survives.
      expect(controller.snapshot.hasLocalSave, isTrue);
      expect(controller.snapshot.savedEntry, isNotNull);
    });

    test('control: says nothing when something can transcribe', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.proceed;
      final controller = _controller(
        audio: audio,
        moments: moments,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();

      expect(controller.snapshot.transcriptionChoiceRequired, isFalse);
      expect(controller.snapshot.hasLocalSave, isTrue);
    });

    test('a recorded "no transcription" is not asked again', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.respectNoTranscription;
      final controller = _controller(
        audio: audio,
        moments: moments,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();

      expect(controller.snapshot.transcriptionChoiceRequired, isFalse);
      expect(controller.snapshot.hasLocalSave, isTrue);
      expect(capability.recordedChoices, isEmpty);
    });

    test('a failed remote leg does not raise the prompt', () async {
      // The transient-failure case: local transcription is fine, the request
      // is not. A flaky connection must not surface a privacy question.
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()
        ..voiceResult = CapturePipelineResult(
          entry: _entry(),
          localSaved: true,
          syncSucceeded: false,
          syncNote: VoiceCaptureCopy.analysisUnavailableNote,
        );
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.proceed;
      final controller = _controller(
        audio: audio,
        moments: moments,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();

      expect(controller.snapshot.phase, CaptureFlowPhase.savedLocal);
      expect(controller.snapshot.transcriptionChoiceRequired, isFalse);
    });

    test('a save that fails outright does not raise the prompt', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments();
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.askOnce;
      final controller = _controller(
        audio: audio,
        moments: moments,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();

      expect(
        controller.snapshot.transcriptionChoiceRequired,
        isFalse,
        reason: 'nothing is saved yet, so there is nothing to ask about',
      );
    });

    test('a capability probe that throws does not raise the prompt', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()..shouldThrow = true;
      final controller = _controller(
        audio: audio,
        moments: moments,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();

      expect(controller.snapshot.transcriptionChoiceRequired, isFalse);
      expect(controller.snapshot.hasLocalSave, isTrue);
    });

    test('declining records the answer and leaves the entry saved', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.askOnce;
      final controller = _controller(
        audio: audio,
        moments: moments,
        consent: _FakeConsent()..granted = false,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();
      final savedBefore = controller.snapshot.savedEntry;

      await controller.resolveTranscriptionChoice(allowRemote: false);

      expect(capability.recordedChoices, [false]);
      expect(controller.snapshot.transcriptionChoiceRequired, isFalse);
      expect(controller.snapshot.savedEntry, savedBefore);
      expect(controller.snapshot.hasLocalSave, isTrue);
      expect(controller.snapshot.phase, CaptureFlowPhase.savedLocal);
    });

    test('accepting records the answer once and closes the prompt', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.askOnce;
      final controller = _controller(
        audio: audio,
        moments: moments,
        consent: _FakeConsent()..granted = false,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();

      await controller.resolveTranscriptionChoice(allowRemote: true);
      // A second tap, e.g. a double press, must not write twice.
      await controller.resolveTranscriptionChoice(allowRemote: true);

      expect(capability.recordedChoices, [true]);
      expect(controller.snapshot.transcriptionChoiceRequired, isFalse);
    });

    test('a store failure while recording does not lose the save', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.askOnce
        ..recordShouldThrow = true;
      final controller = _controller(
        audio: audio,
        moments: moments,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();
      await controller.resolveTranscriptionChoice(allowRemote: false);

      expect(controller.snapshot.hasLocalSave, isTrue);
      expect(controller.snapshot.errorMessage, isNull);
    });

    test('an unconfirmed language raises the language prompt, not the upload '
        'prompt', () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.askSpeechLanguage;
      final controller = _controller(
        audio: audio,
        moments: moments,
        consent: _FakeConsent()..granted = false,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();

      expect(controller.snapshot.speechLocaleChoiceRequired, isTrue);
      expect(
        controller.snapshot.transcriptionChoiceRequired,
        isFalse,
        reason: 'picking a language is not a decision about uploading',
      );
      expect(controller.snapshot.hasLocalSave, isTrue);
    });

    test('confirming a language records it once and closes the prompt',
        () async {
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.askSpeechLanguage;
      final controller = _controller(
        audio: audio,
        moments: moments,
        transcriptionCapability: capability,
      );
      final gujarati = ConfirmedSpeechLocale.confirmed('gu-IN')!;

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();
      await controller.resolveSpeechLocale(gujarati);
      await controller.resolveSpeechLocale(gujarati);

      expect(capability.recordedLocales, [gujarati]);
      expect(controller.snapshot.speechLocaleChoiceRequired, isFalse);
    });

    test('a failed language write leaves the question open', () async {
      // An answer that did not persist has not been given. Closing the prompt
      // anyway would leave on-device transcription off with nothing on screen
      // to explain it.
      final audio = _FakeAudio()..lastFile = tempAudioFile;
      final moments = _FakeMoments()..voiceResult = _result(analysis: false);
      final capability = _FakeTranscriptionCapability()
        ..outcome = TranscriptionCapabilityOutcome.askSpeechLanguage
        ..recordLocaleShouldThrow = true;
      final controller = _controller(
        audio: audio,
        moments: moments,
        transcriptionCapability: capability,
      );

      await controller.startVoiceCapture();
      await controller.stopVoiceCapture();
      await controller.resolveSpeechLocale(
        ConfirmedSpeechLocale.confirmed('en-GB')!,
      );

      expect(controller.snapshot.speechLocaleChoiceRequired, isTrue);
      expect(controller.snapshot.hasLocalSave, isTrue);
      expect(controller.snapshot.errorMessage, isNull);
    });
  });
}
