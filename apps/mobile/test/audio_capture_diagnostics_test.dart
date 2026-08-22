import 'dart:io';

import 'package:archiveme_mobile/features/voice_capture/audio/audio_capture_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioCaptureDiagnostics', () {
    test('guesses audio/mp4 for m4a files', () {
      expect(
        AudioCaptureDiagnostics.guessMimeFromPath('/tmp/vm_rec_1.m4a'),
        'audio/mp4',
      );
    });

    test('uses audio/mp4 upload content type for m4a', () {
      expect(
        AudioCaptureDiagnostics.uploadContentTypeForPath('/tmp/recording.m4a'),
        'audio/mp4',
      );
    });

    test('uses audio/wav upload content type for wav', () {
      expect(
        AudioCaptureDiagnostics.uploadContentTypeForPath('/tmp/recording.wav'),
        'audio/wav',
      );
    });

    test('logs first 16 bytes as hex', () {
      final dir = Directory.systemTemp.createTempSync('vm_audio_diag_');
      final file = File('${dir.path}/sample.m4a')
        ..writeAsBytesSync(List<int>.generate(20, (i) => i));

      AudioCaptureDiagnostics.logCapturedFile(file, durationMs: 4200);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), 20);
    });
  });
}