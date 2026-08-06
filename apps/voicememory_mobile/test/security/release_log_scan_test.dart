import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio diag log guards sensitive fields in release mode', () {
    final content = File(
      'lib/features/voice_capture/audio/audio_diag_log.dart',
    ).readAsStringSync();
    expect(content, contains('if (kReleaseMode)'));
    expect(content, contains('bytesBucket'));
    // Sensitive debugPrint lines must appear only after the release early-return.
    final releaseReturn = content.indexOf('if (kReleaseMode)');
    final firstBytesLog = content.indexOf("firstBytes=\$firstBytesHex");
    expect(releaseReturn, greaterThan(-1));
    expect(firstBytesLog, greaterThan(releaseReturn));
  });
}
