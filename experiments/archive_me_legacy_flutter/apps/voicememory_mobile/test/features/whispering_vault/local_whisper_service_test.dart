import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/whispering_vault/local_whisper_service.dart';

void main() {
  test('requires a provisioned embedded model without downloading', () async {
    final service = LocalWhisperService(driver: _FakeDriver(ready: false));

    await expectLater(
      service.loadModel(),
      throwsA(
        isA<LocalWhisperException>().having(
          (error) => error.message,
          'message',
          contains('not installed'),
        ),
      ),
    );
    expect(service.isLoaded, isFalse);
  });

  test(
    'loads and transcribes a known offline WAV fixture accurately',
    () async {
      final driver = _FakeDriver(transcript: 'A calm offline reflection.');
      final service = LocalWhisperService(driver: driver);
      await service.loadModel();

      final transcript = await service.transcribeBuffer(_wav());

      expect(transcript, 'A calm offline reflection.');
      expect(driver.transcriptions, 1);
      expect(service.isLoaded, isTrue);
    },
  );

  test('streams progressive local transcription revisions', () async {
    final driver = _FakeDriver(
      transcripts: ['First thought', 'First thought expanded'],
    );
    final service = LocalWhisperService(driver: driver);
    await service.loadModel();

    final revisions = await service
        .transcribeStream(
          Stream.fromIterable([
            WhisperAudioBuffer(wavBytes: _wav(), isFinal: false),
            WhisperAudioBuffer(wavBytes: _wav(), isFinal: true),
          ]),
        )
        .toList();

    expect(revisions.map((item) => item.text), [
      'First thought',
      'First thought expanded',
    ]);
    expect(revisions.last.isFinal, isTrue);
    expect(revisions.last.revision, 2);
  });
}

Uint8List _wav() => Uint8List.fromList([
  0x52,
  0x49,
  0x46,
  0x46,
  ...List<int>.filled(4, 0),
  0x57,
  0x41,
  0x56,
  0x45,
  ...List<int>.filled(32, 0),
  ...List<int>.filled(3200, 1),
]);

final class _FakeDriver implements LocalWhisperDriver {
  _FakeDriver({
    this.ready = true,
    this.transcript = 'offline transcript',
    this.transcripts,
  });

  final bool ready;
  final String transcript;
  final List<String>? transcripts;
  int transcriptions = 0;

  @override
  Future<bool> isModelReady() async => ready;

  @override
  Future<String> transcribe(File wavFile) async {
    expect(wavFile.existsSync(), isTrue);
    expect(wavFile.lengthSync(), greaterThan(44));
    final index = transcriptions++;
    final progressive = transcripts;
    return progressive == null ? transcript : progressive[index];
  }
}
