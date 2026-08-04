import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/whispering_vault/local_whisper_service.dart';
import 'package:voicememory_mobile/services/analytics/ffi_safety_monitor.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';
import 'package:voicememory_mobile/services/security/native_boundary_fuzzer.dart';

void main() {
  tearDown(() => FFISafetyMonitor.install(null));

  test('malformed pointer, allocation, and UTF-8 corpus fails closed', () {
    final monitor = FFISafetyMonitor();
    FFISafetyMonitor.install(monitor);

    final findings = const NativeBoundaryFuzzer().run();

    expect(findings, hasLength(12));
    expect(findings.every((finding) => finding.rejected), isTrue);
    expect(
      findings.map((finding) => finding.vector).toSet(),
      NativeFuzzVector.values.toSet(),
    );
    monitor.assertNoLeaks();
  });

  test('strict decoder rejects invalid UTF-8 without native dispatch', () {
    expect(
      () => NativeBoundaryContract.decodeStrictUtf8(
        Uint8List.fromList(const [0xf0, 0x28, 0x8c, 0x28]),
        maximum: 32,
      ),
      throwsA(isA<NativeBoundaryViolation>()),
    );
  });

  test('Whisper rejects malformed WAV bytes before its driver', () async {
    final driver = _WhisperProbeDriver();
    final service = LocalWhisperService(driver: driver);
    await service.loadModel();

    await expectLater(
      service.transcribeBuffer(Uint8List(44)),
      throwsA(isA<LocalWhisperException>()),
    );
    expect(driver.dispatched, isFalse);
  });

  test('Apex ledger balances a Whisper operation', () async {
    final monitor = FFISafetyMonitor(rssPressureThresholdBytes: 1 << 40);
    FFISafetyMonitor.install(monitor);
    final driver = _WhisperProbeDriver();
    final service = LocalWhisperService(driver: driver);
    await service.loadModel();
    final wav = Uint8List(44)
      ..setRange(0, 4, const [0x52, 0x49, 0x46, 0x46])
      ..setRange(8, 12, const [0x57, 0x41, 0x56, 0x45]);

    expect(await service.transcribeBuffer(wav), 'must not run');
    expect(driver.dispatched, isTrue);
    monitor.assertNoLeaks();
    await monitor.dispose();
  });

  test(
    'sqlite-vec rejects oversized dimensions before opening native state',
    () async {
      await expectLater(
        SqliteVecVectorStore.open(
          databasePath: '${Directory.systemTemp.path}/never-created.sqlite3',
          dimensions: 8193,
        ),
        throwsArgumentError,
      );
    },
  );
}

final class _WhisperProbeDriver implements LocalWhisperDriver {
  bool dispatched = false;

  @override
  Future<bool> isModelReady() async => true;

  @override
  Future<String> transcribe(File wavFile) async {
    dispatched = true;
    return 'must not run';
  }
}
