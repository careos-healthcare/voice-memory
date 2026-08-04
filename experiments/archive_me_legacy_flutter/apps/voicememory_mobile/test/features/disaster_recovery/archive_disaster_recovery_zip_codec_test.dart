import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/disaster_recovery/archive_disaster_recovery_zip_codec.dart';

void main() {
  test('production ZIP codec round trips binary entries', () async {
    const codec = ArchiveDisasterRecoveryZipCodec();
    final encoded = await codec.encode({
      'manifest.json': Uint8List.fromList([1, 2, 3]),
      'audio/voice.wav': Uint8List.fromList([0, 255, 7]),
    });

    final decoded = await codec.decode(encoded);

    expect(decoded.keys, containsAll(['manifest.json', 'audio/voice.wav']));
    expect(decoded['audio/voice.wav'], [0, 255, 7]);
  });

  test('production ZIP codec rejects corrupt archives', () async {
    const codec = ArchiveDisasterRecoveryZipCodec();

    expect(
      () => codec.decode(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
  });
}
