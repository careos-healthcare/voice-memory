import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/application/live_voice_pitch_contour_collector.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_cipher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Voice Performance & Memory Load Suite (30+ Min Session)', () {
    late LiveVoicePitchContourCollector pitchCollector;
    late VaultCipher cipher;
    late SecretKey testKey;

    setUp(() async {
      pitchCollector = LiveVoicePitchContourCollector();
      cipher = VaultCipher();
      testKey = await AesGcm.with256bits().newSecretKey();
    });

    test('30-minute pitch contour collector maintains memory bounds', () {
      // 30 mins @ 20Hz = 36,000 frames
      const totalFrames = 36000;

      for (var i = 0; i < totalFrames; i++) {
        pitchCollector.addFrameHz(120.0 + (i % 60));
      }

      final contour = pitchCollector.getContour();
      // Sliding-window retention prevents unbounded array growth.
      expect(
        contour.length,
        lessThanOrEqualTo(LiveVoicePitchContourCollector.maxRetainedSamples),
      );
      expect(contour, isNotEmpty);
    });

    test('VaultCipher vault frame encryption stays sub-50ms', () async {
      // One 20ms PCM16 LE frame at 16 kHz mono (~640 bytes).
      final payload = List<int>.generate(640, (index) => index % 256);

      final watch = Stopwatch()..start();
      final encryptedRecord = await cipher.encryptVaultFrameRecord(
        rawBytes: payload,
        secretKey: testKey,
      );
      watch.stop();

      expect(
        encryptedRecord.length,
        payload.length + VaultCipher.authenticatedOverhead + 4,
      );
      expect(watch.elapsedMilliseconds, lessThan(50));

      final decryptWatch = Stopwatch()..start();
      final decrypted = await cipher.decryptVaultFrameRecord(
        encryptedRecordBytes: encryptedRecord,
        secretKey: testKey,
      );
      decryptWatch.stop();

      expect(decrypted, payload);
      expect(decryptWatch.elapsedMilliseconds, lessThan(50));
    });

    test('VaultCipher 1MB payload round-trip stays within stress bounds', () async {
      final payload = List<int>.generate(1024 * 1024, (index) => index % 256);

      final watch = Stopwatch()..start();
      final encryptedRecord = await cipher.encryptVaultFrameRecord(
        rawBytes: payload,
        secretKey: testKey,
      );
      watch.stop();

      expect(
        encryptedRecord.length,
        payload.length + VaultCipher.authenticatedOverhead + 4,
      );
      // Full-megabyte encrypt is a stress case; debug VM crypto is slower than release.
      expect(watch.elapsedMilliseconds, lessThan(250));

      final decryptWatch = Stopwatch()..start();
      final decrypted = await cipher.decryptVaultFrameRecord(
        encryptedRecordBytes: encryptedRecord,
        secretKey: testKey,
      );
      decryptWatch.stop();

      expect(decrypted, payload);
      // Debug VM decrypt can spike on large payloads; release stays well under this.
      expect(decryptWatch.elapsedMilliseconds, lessThan(250));
    });
  });
}
