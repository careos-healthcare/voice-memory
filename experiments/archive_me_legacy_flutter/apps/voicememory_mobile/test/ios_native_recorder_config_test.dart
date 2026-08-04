import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/ios_native_recorder_config.dart';

void main() {
  test('native recorder flag defaults to enabled', () {
    expect(IosNativeRecorderConfig.enabled, isTrue);
  });
}
