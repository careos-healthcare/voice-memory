import 'package:archiveme_mobile/features/voice_capture/audio/audio_diag_log.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/ios_native_audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    IosNativeAudioSession.testInvoker = null;
  });

  test(
    'configureForCapture logs session snapshot from native channel',
    () async {
      IosNativeAudioSession.testInvoker = (mode) async {
        return IosAudioSessionSnapshot(
          configured: true,
          category: 'playAndRecord',
          mode: mode.value,
          sampleRate: 44100,
          inputChannels: 1,
          outputVolume: 0.75,
        );
      };

      final lines = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        lines.add(message ?? '');
      };
      addTearDown(() {
        debugPrint = oldDebugPrint;
      });

      final snapshot = await IosNativeAudioSession.configureForCapture(
        
      );

      expect(snapshot?.configured, isTrue);
      expect(snapshot?.mode, 'spokenAudio');
      expect(
        lines.any(
          (line) =>
              line.contains('ARCHIVEME_IOS_AUDIO_SESSION') &&
              line.contains('sampleRate=44100') &&
              line.contains('inputChannels=1'),
        ),
        isTrue,
      );
    },
  );

  test('route diagnostics helpers emit expected prefixes', () {
    final lines = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      lines.add(message ?? '');
    };
    addTearDown(() {
      debugPrint = oldDebugPrint;
    });

    AudioDiagLog.iosAudioRoute(
      inputs: 'iPad Microphone:MicrophoneBuiltIn',
      outputs: 'Speaker:Speaker',
    );
    AudioDiagLog.iosAudioInput(
      portName: 'iPad Microphone',
      portType: 'MicrophoneBuiltIn',
    );
    AudioDiagLog.iosAudioAvailableInputs(count: 1, names: 'iPad Microphone');

    expect(
      lines.any((line) => line.startsWith('ARCHIVEME_IOS_AUDIO_ROUTE')),
      isTrue,
    );
    expect(
      lines.any((line) => line.startsWith('ARCHIVEME_IOS_AUDIO_INPUT')),
      isTrue,
    );
    expect(
      lines.any(
        (line) => line.startsWith('ARCHIVEME_IOS_AUDIO_AVAILABLE_INPUTS'),
      ),
      isTrue,
    );
  });
}