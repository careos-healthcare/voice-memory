import 'dart:typed_data';

import 'package:archiveme_mobile/core/hardware/hardware_monitor_channel.dart';
import 'package:archiveme_mobile/core/hardware/hardware_state_provider.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_summary_prompts.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_summary_service.dart';
import 'package:archiveme_mobile/features/audio/transcription/sherpa_diarization_service.dart';
import 'package:archiveme_mobile/features/audio/transcription/speaker_transcript.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unplugged high heat defers heavy work until forced', () async {
    final scheduler = HeavyWorkScheduler();
    var runs = 0;
    final service = GemmaSummaryService(
      snapshot: const HardwareSnapshot(
        batteryPercent: 40,
        isCharging: false,
        thermalStatus: DeviceThermalStatus.serious,
      ),
      scheduler: scheduler,
      completer: ({required systemPrompt, required userPrompt}) async {
        runs += 1;
        return 'Polished note';
      },
    );

    final deferred = await service.summarize(
      transcript: 'Need to call Sam tomorrow.',
      style: GemmaSummaryStyle.smartSummary,
    );
    expect(deferred.deferred, isTrue);
    expect(runs, 0);
    expect(scheduler.pendingCount, 1);

    final forced = await service.summarize(
      transcript: 'Need to call Sam tomorrow.',
      style: GemmaSummaryStyle.actionItems,
      forceImmediate: true,
    );
    expect(forced.deferred, isFalse);
    expect(forced.text, 'Polished note');
    expect(runs, 1);
  });

  test('summary prompts cover the three local formats', () {
    expect(
      GemmaSummaryPrompts.systemPrompt(GemmaSummaryStyle.smartSummary),
      contains('Smart Summary'),
    );
    expect(
      GemmaSummaryPrompts.systemPrompt(GemmaSummaryStyle.actionItems),
      contains('Action Items'),
    );
    expect(
      GemmaSummaryPrompts.systemPrompt(GemmaSummaryStyle.diaryFormat),
      contains('Diary Format'),
    );
  });

  test('diarization labels speakers and groups the transcript', () async {
    final service = SherpaDiarizationService(
      processSamples: (samples) async {
        return const [
          TimedSpeakerSpan(start: 0, end: 1, speaker: 0),
          TimedSpeakerSpan(start: 1, end: 3, speaker: 1),
        ];
      },
    );

    final transcript = await service.diarize(
      transcript: 'Hello there friend today',
      samples: Float32List(4),
      segmentationModelPath: '/missing/seg.onnx',
      embeddingModelPath: '/missing/emb.onnx',
    );

    expect(transcript.turns.map((turn) => turn.speakerLabel), [
      'Speaker A',
      'Speaker B',
    ]);
    expect(transcript.plainText, 'Hello there friend today');
  });

  test('hardware snapshot marks unplugged serious heat as deferred', () {
    final snapshot = HardwareSnapshot.fromMap({
      'batteryPercent': 55,
      'isCharging': false,
      'thermalStatus': 'serious',
    });
    expect(snapshot.shouldDeferHeavyWork, isTrue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gemmaSummaryProvider.notifier)
        .save(
          entryId: 'moment-1',
          text: 'A short summary.',
        );
    expect(
      container.read(gemmaSummaryProvider)['moment-1'],
      'A short summary.',
    );
  });
}
