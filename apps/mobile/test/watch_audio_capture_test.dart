import 'package:archiveme_mobile/features/watch/watch_audio_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WatchAudioCapture parses legacy path string', () {
    final capture = WatchAudioCapture.fromPlatform('/tmp/watch_capture.m4a');
    expect(capture?.path, '/tmp/watch_capture.m4a');
    expect(capture?.ingestKey, 'watch_capture.m4a');
  });

  test('WatchAudioCapture parses structured payload', () {
    final capture = WatchAudioCapture.fromPlatform({
      'path': '/tmp/watch_inbox/watch_capture_1.m4a',
      'durationSeconds': 12,
      'capturedAt': '2026-01-15T12:00:00.000Z',
    });
    expect(capture?.durationSeconds, 12);
    expect(
      capture?.ingestKey,
      'watch_capture_1.m4a@2026-01-15T12:00:00.000Z',
    );
  });
}