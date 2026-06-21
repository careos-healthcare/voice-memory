import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/mic_capture_input_health.dart';

void main() {
  group('MicCaptureInputHealth', () {
    test('detects built-in iPad microphone by name and type', () {
      expect(
        MicCaptureInputHealth.isBuiltInMic(
          portName: 'iPad Microphone',
          portType: 'MicrophoneBuiltIn',
        ),
        isTrue,
      );
      expect(
        MicCaptureInputHealth.isBuiltInMic(portType: 'BuiltInMic'),
        isTrue,
      );
      expect(
        MicCaptureInputHealth.isBuiltInMic(
          portName: 'AirPods Pro',
          portType: 'BluetoothHFP',
        ),
        isFalse,
      );
    });

    test('detects bluetooth and headset inputs', () {
      expect(
        MicCaptureInputHealth.isBluetoothOrHeadset(portType: 'BluetoothHFP'),
        isTrue,
      );
      expect(
        MicCaptureInputHealth.isBluetoothOrHeadset(portType: 'HeadsetMic'),
        isTrue,
      );
      expect(
        MicCaptureInputHealth.isBluetoothOrHeadset(portType: 'BuiltInMic'),
        isFalse,
      );
    });

    test('shouldShowBuiltInSilentGuidance only for silent built-in mic', () {
      expect(
        MicCaptureInputHealth.shouldShowBuiltInSilentGuidance(
          likelySilent: true,
          portName: 'iPad Microphone',
          portType: 'BuiltInMic',
        ),
        isTrue,
      );
      expect(
        MicCaptureInputHealth.shouldShowBuiltInSilentGuidance(
          likelySilent: true,
          portName: 'AirPods Pro',
          portType: 'BluetoothHFP',
        ),
        isFalse,
      );
      expect(
        MicCaptureInputHealth.shouldShowBuiltInSilentGuidance(
          likelySilent: false,
          portName: 'iPad Microphone',
          portType: 'BuiltInMic',
        ),
        isFalse,
      );
    });

    test('recommendation is bluetooth_or_type for silent built-in mic', () {
      expect(
        MicCaptureInputHealth.recommendation(
          likelySilent: true,
          portName: 'iPad Microphone',
          portType: 'BuiltInMic',
        ),
        'bluetooth_or_type',
      );
      expect(
        MicCaptureInputHealth.recommendation(
          likelySilent: false,
          portName: 'iPad Microphone',
          portType: 'BuiltInMic',
        ),
        isNull,
      );
    });

    test('debugInputLabel maps common routes', () {
      expect(
        MicCaptureInputHealth.debugInputLabel(
          portName: 'Chirag\'s AirPods Pro',
          portType: 'BluetoothHFP',
        ),
        'AirPods',
      );
      expect(
        MicCaptureInputHealth.debugInputLabel(
          portName: 'iPad Microphone',
          portType: 'BuiltInMic',
        ),
        'iPad Microphone',
      );
    });
  });
}
