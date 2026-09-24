import 'dart:io';

import 'package:archiveme_mobile/features/capture_flow/ui/capture_flow_panels.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/offline_first_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/offline_transcription_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/whisper_kit_channel.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final locale = ConfirmedSpeechLocale.confirmed('en-US');

  late File audio;

  setUp(() async {
    audio = File(
      '${Directory.systemTemp.path}/offline_whisper_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    await audio.writeAsBytes(List<int>.filled(32, 1));
  });

  tearDown(() async {
    if (audio.existsSync()) {
      await audio.delete();
    }
  });

  test('unsupported hardware uses the cloud endpoint', () async {
    final stages = <PipelineStage>[];
    var cloudCalls = 0;
    final service = OfflineFirstTranscriptionService(
      hardwareSupported: () async => false,
    );

    final result = await service.transcribe(
      audioFile: audio,
      speechLocale: locale,
      onStage: stages.add,
      allowCloudFallback: true,
      transcribeInCloud: () async {
        cloudCalls += 1;
        return 'cloud transcript';
      },
    );

    expect(result.route, OfflineTranscriptionRoute.cloud);
    expect(cloudCalls, 1);
    expect(stages, isEmpty);
  });

  test('local Whisper runs before any cloud call', () async {
    final stages = <PipelineStage>[];
    var cloudCalls = 0;
    final service = OfflineFirstTranscriptionService(
      hardwareSupported: () async => true,
      modelReady: () async => false,
      downloadModel: () async => true,
      transcribeLocally: (file, speechLocale) async => 'on device words',
    );

    final result = await service.transcribe(
      audioFile: audio,
      speechLocale: locale,
      onStage: stages.add,
      allowCloudFallback: true,
      transcribeInCloud: () async {
        cloudCalls += 1;
        return 'cloud transcript';
      },
    );

    expect(result.usedLocalWhisper, isTrue);
    expect(result.transcript, 'on device words');
    expect(cloudCalls, 0);
    expect(stages, [
      PipelineStage.downloadingLocalModel,
      PipelineStage.processingOnDevice,
    ]);
  });

  test('a failed on-device pass falls back to the cloud endpoint', () async {
    final stages = <PipelineStage>[];
    var cloudCalls = 0;
    final service = OfflineFirstTranscriptionService(
      hardwareSupported: () async => true,
      modelReady: () async => true,
      transcribeLocally: (file, speechLocale) async {
        throw StateError('engine failed');
      },
    );

    final result = await service.transcribe(
      audioFile: audio,
      speechLocale: locale,
      onStage: stages.add,
      allowCloudFallback: true,
      transcribeInCloud: () async {
        cloudCalls += 1;
        return 'cloud transcript';
      },
    );

    expect(result.route, OfflineTranscriptionRoute.cloud);
    expect(result.cloudValue, 'cloud transcript');
    expect(cloudCalls, 1);
    expect(stages, [PipelineStage.processingOnDevice]);
  });

  test(
    'never-send skips the cloud endpoint when local Whisper fails',
    () async {
      var cloudCalls = 0;
      final service = OfflineFirstTranscriptionService(
        hardwareSupported: () async => true,
        modelReady: () async => true,
        transcribeLocally: (file, speechLocale) async => '',
      );

      final result = await service.transcribe(
        audioFile: audio,
        speechLocale: locale,
        onStage: (_) {},
        allowCloudFallback: false,
        transcribeInCloud: () async {
          cloudCalls += 1;
          return 'cloud transcript';
        },
      );

      expect(result.route, OfflineTranscriptionRoute.unavailable);
      expect(cloudCalls, 0);
    },
  );

  test('WhisperKit channel returns on-device text', () async {
    const channel = MethodChannel(WhisperKitChannel.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'transcribeFile') return 'whisper kit line';
          return false;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final text = await WhisperKitChannel().transcribeFile(
      audioPath: audio.path,
      localeIdentifier: 'en-US',
    );
    expect(text, 'whisper kit line');
  });

  testWidgets('capture shows the on-device model states', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CaptureBusyPanel(
                label: OfflineTranscriptionCopy.downloadingLocalModel,
              ),
              CaptureBusyPanel(
                label: OfflineTranscriptionCopy.processingOnDevice,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Downloading local model'), findsOneWidget);
    expect(find.text('Processing on-device'), findsOneWidget);
    expect(
      offlineTranscriptionStageLabel(PipelineStage.downloadingLocalModel),
      'Downloading local model',
    );
    expect(
      offlineTranscriptionStageLabel(PipelineStage.processingOnDevice),
      'Processing on-device',
    );
  });
}
