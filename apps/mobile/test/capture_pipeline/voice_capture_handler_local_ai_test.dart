import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/reflections/local_ai_pipeline.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_facade.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_pipeline_test_support.dart';

class _StubLocalAiPort implements VoiceLocalAiPort {
  _StubLocalAiPort({
    required this.transcript,
    required this.reflection,
    this.confidenceThreshold = 0.9,
  });

  final String transcript;
  final Reflection reflection;
  @override
  final double confidenceThreshold;

  @override
  Future<LocalAiPipelineResult> processAudio({
    required File audioFile,
    required int durationSeconds,
    required String entryId,
    String? captureToken,
    String? idempotencyKey,
    String? existingTranscript,
  }) async {
    return LocalAiPipelineResult(
      transcript: transcript,
      reflection: _toDto(reflection),
      overallConfidence: confidenceThreshold,
      transcriptionConfidence: confidenceThreshold,
      reflectionConfidence: confidenceThreshold,
      usedLocalStt: true,
      usedLocalLlm: true,
    );
  }

  @override
  Future<LocalAiPipelineResult> processTranscript({
    required String transcript,
    required int durationSeconds,
    required String entryId,
    String? captureToken,
    String? idempotencyKey,
  }) {
    return processAudio(
      audioFile: File('/tmp/unused.wav'),
      durationSeconds: durationSeconds,
      entryId: entryId,
      existingTranscript: transcript,
    );
  }
}

void main() {
  group('VoiceCaptureHandler local AI first', () {
    late Directory tempDir;
    late JournalStore journal;
    late MobilePrefsStore prefs;
    late RemoteProcessingConsentStore consentStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('voice_local_ai_');
      journal = JournalStore(file: File('${tempDir.path}/journal.json'));
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      consentStore = RemoteProcessingConsentStore(prefs);
      await consentStore.withdraw();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves with local reflection without remote transcribe or analyze', () async {
      final api = _NoRemoteCaptureApi();
      final built = await buildCapturePipelineFacade(
        prefs: prefs,
        journal: journal,
        consentStore: consentStore,
        api: api,
      );
      final facade = CapturePipelineFacade.standard(
        built.facade.dependencies.copyWith(
          localAiPipeline: _StubLocalAiPort(
            transcript:
                'Work has been heavy but I keep taking on more. '
                'Tomorrow I will leave on time and rest.',
            reflection: const Reflection(
              mood: 'reflective',
              emotionalIntensity: 6,
              recurringThemes: ['work'],
              exactLanguagePattern: 'keep taking on more',
              concreteObservation: 'Work has been heavy',
              repeatedSignal: 'Repeated "work" in this entry.',
              tensionOrContradiction: 'wants rest but keeps accepting more work',
              nextSmallAction: 'leave on time and rest',
            ),
          ),
        ),
      );

      final wav = await _writeTestWav(tempDir);
      final result = (await facade.run(
        audioFile: wav,
        durationSeconds: 8,
      )).getOrThrow();

      expect(result.localSaved, isTrue);
      expect(result.analysisSucceeded, isTrue);
      expect(result.syncSucceeded, isFalse);
      expect(api.transcribeCalls, 0);
      expect(api.analyzeCalls, 0);

      final saved = await journal.loadAll();
      expect(saved, hasLength(1));
      expect(saved.single.transcript, contains('Work has been heavy'));
      expect(saved.single.reflection.emotionalIntensity, 6);
      expect(saved.single.reflection.tensionOrContradiction, isNotNull);
    });
  });
}

class _NoRemoteCaptureApi extends AnalyzeCaptureApi {
  var transcribeCalls = 0;
  var analyzeCalls = 0;

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    transcribeCalls += 1;
    throw StateError('remote transcribe should not run');
  }

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    analyzeCalls += 1;
    throw StateError('remote analyze should not run');
  }
}

Future<File> _writeTestWav(Directory dir) async {
  final file = File('${dir.path}/voice.wav');
  final pcmSamples = 16000;
  final dataSize = pcmSamples * 2;
  final buffer = BytesBuilder();
  buffer.add('RIFF'.codeUnits);
  buffer.add(_le32(36 + dataSize));
  buffer.add('WAVE'.codeUnits);
  buffer.add('fmt '.codeUnits);
  buffer.add(_le32(16));
  buffer.add(_le16(1));
  buffer.add(_le16(1));
  buffer.add(_le32(16000));
  buffer.add(_le32(32000));
  buffer.add(_le16(2));
  buffer.add(_le16(16));
  buffer.add('data'.codeUnits);
  buffer.add(_le32(dataSize));
  for (var i = 0; i < pcmSamples; i++) {
    buffer.add([i.isEven ? 40 : 0, 0]);
  }
  await file.writeAsBytes(buffer.toBytes());
  expect(await file.length(), greaterThan(VoiceCaptureQuality.minAudioBytes));
  return file;
}

Uint8List _le16(int value) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

Uint8List _le32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

ReflectionDto _toDto(Reflection reflection) {
  return ReflectionDto(
    mood: reflection.mood,
    emotionalIntensity: reflection.emotionalIntensity,
    recurringThemes: reflection.recurringThemes,
    exactLanguagePattern: reflection.exactLanguagePattern,
    concreteObservation: reflection.concreteObservation,
    repeatedSignal: reflection.repeatedSignal,
    tensionOrContradiction: reflection.tensionOrContradiction,
    avoidedOrVagueArea: reflection.avoidedOrVagueArea,
    nextSmallAction: reflection.nextSmallAction,
    patternObservations: reflection.patternObservations,
  );
}
