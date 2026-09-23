import 'package:archiveme_mobile/features/playback/local_ai_coach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const coach = LocalAICoach();

  test('reads hesitation and retained silence on device', () {
    final reading = coach.duringPlayback(
      hesitation: const HesitationSignalSample(
        gapBeforeSpeechMs: 14000,
        pauseCount: 1,
      ),
      silence: const SilenceRetentionSignalSample(
        silenceBeforeSpeechMs: 2200,
        retainedSilenceMs: 800,
      ),
    );

    expect(reading.hesitation, isTrue);
    expect(reading.silenceRetained, isTrue);
    expect(reading.note, contains('pause'));
    expect(reading.note, contains('quiet'));
  });

  test('steady playback stays unmarked', () {
    final reading = coach.duringPlayback(
      hesitation: const HesitationSignalSample(gapBeforeSpeechMs: 400),
      silence: const SilenceRetentionSignalSample(
        silenceBeforeSpeechMs: 200,
        retainedSilenceMs: 0,
      ),
    );

    expect(reading.hesitation, isFalse);
    expect(reading.silenceRetained, isFalse);
    expect(reading.note, 'Playback stayed steady.');
  });

  test('turned-off coaching switches drop that part of the reading', () {
    final reading = coach.duringPlayback(
      hesitation: const HesitationSignalSample(
        gapBeforeSpeechMs: 14000,
        pauseCount: 1,
      ),
      silence: const SilenceRetentionSignalSample(
        silenceBeforeSpeechMs: 2200,
        retainedSilenceMs: 800,
      ),
      parameters: const LocalAiCoachingParameters(
        noticePauses: false,
        keepQuietStretches: false,
        writeShortNote: false,
      ),
    );

    expect(reading.hesitation, isFalse);
    expect(reading.silenceRetained, isFalse);
    expect(reading.note, isEmpty);
  });
}
