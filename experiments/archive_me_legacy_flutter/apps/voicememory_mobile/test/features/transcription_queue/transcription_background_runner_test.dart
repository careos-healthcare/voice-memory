import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_event_engine.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_background_runner.dart';

void main() {
  test('known background task bootstraps a minimal worker', () async {
    var bootstraps = 0;

    final result = await runTranscriptionBackgroundTask(
      WorkmanagerTranscriptionScheduler.taskName,
      bootstrap: () async => bootstraps++,
    );

    expect(result, isTrue);
    expect(bootstraps, 1);
  });

  test('bootstrap failure asks the OS to retry', () async {
    final result = await runTranscriptionBackgroundTask(
      WorkmanagerTranscriptionScheduler.taskName,
      bootstrap: () async => throw StateError('plugin unavailable'),
    );

    expect(result, isFalse);
  });

  test('unknown background task is ignored', () async {
    var bootstraps = 0;

    final result = await runTranscriptionBackgroundTask(
      'other.task',
      bootstrap: () async => bootstraps++,
    );

    expect(result, isTrue);
    expect(bootstraps, 0);
  });

  test('Catalyst task dispatches one local background tick', () async {
    var ticks = 0;

    final result = await runTranscriptionBackgroundTask(
      WorkmanagerCatalystScheduler.taskName,
      catalystTick: () async => ticks++,
    );

    expect(result, isTrue);
    expect(ticks, 1);
  });
}
