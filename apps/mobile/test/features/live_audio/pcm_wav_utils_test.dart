import 'package:archiveme_mobile/features/live_audio/infrastructure/pcm_wav_utils.dart';
import 'package:archiveme_mobile/features/live_audio/live_audio_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wrapPcm16LeInWav produces RIFF header with PCM data', () {
    final wav = wrapPcm16LeInWav(
      const [1, 0, 2, 0],
      sampleRateHz: liveOutputSampleRateHz,
    );
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 44 + 4);
  });
}