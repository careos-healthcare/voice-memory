import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';

void main() {
  test('RecordingException exposes message', () {
    final e = RecordingException('mic denied');
    expect(e.toString(), 'mic denied');
  });

  test('RecordingPhase enum covers permission states', () {
    expect(RecordingPhase.permissionDenied, isNot(RecordingPhase.ready));
    expect(RecordingPhase.values, contains(RecordingPhase.permissionDenied));
  });
}
