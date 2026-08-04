import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android recorder requires only foreground microphone permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(
      manifest,
      contains(
        'android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" '
        'tools:node="remove"',
      ),
    );
  });

  // The live duplex capture contract was removed with lib/features/live_audio.
  // WebRTC-style live capture is a prohibited direction in the V1 contract and
  // that directory is on its prohibited list, so asserting the source still
  // exists would require reintroducing the feature. The anti-feature guard now
  // owns this ground by failing if any Dart file reappears there.

  test('Android lifecycle guards partial starts and worker shutdown', () {
    final source = File(
      'android/app/src/main/kotlin/com/voicememory/mobile/audio/'
      'AndroidNativeVoiceRecorder.kt',
    ).readAsStringSync();

    expect(source, contains('var selectedRecord: AudioRecord? = null'));
    expect(source, contains('var output: RandomAccessFile? = null'));
    expect(source, contains('captureWorker?.isAlive == true'));
    expect(source, contains('incomplete WAV was discarded'));
    expect(source, contains('"currentDb" to latestDb'));
    expect(source, contains('val cleanupFailure = RecorderStopCleanup.run('));
    expect(source, contains('releaseResources = { releaseSession(capture) }'));
    expect(source, contains('clearWorker = { worker = null }'));
    expect(source, contains('clearActive = { active = null }'));
    expect(
      source,
      contains(
        'discardIncompleteOutput = { discardIncompleteOutput(capture.file) }',
      ),
    );
    expect(source, contains('AcousticEchoCanceler.create(audioSessionId)'));
    expect(source, contains('NoiseSuppressor.create(audioSessionId)'));
    expect(source, contains('AutomaticGainControl.create(audioSessionId)'));
    expect(
      source,
      contains('val confirmedEnabled = runCatching { effect.enabled }'),
    );
    expect(source, contains('capture.processingEffects.release()'));
    expect(
      source,
      contains('if (invoked.compareAndSet(false, true)) action()'),
    );
  });

  test('iOS parses shared controls and reports platform-managed state', () {
    final source = File(
      'ios/Runner/IosNativeVoiceRecorder.swift',
    ).readAsStringSync();

    expect(source, contains('values["acousticEchoCancellation"]'));
    expect(source, contains('values["noiseSuppression"]'));
    expect(source, contains('values["automaticGainControl"]'));
    expect(source, contains('requestedMode = .voiceChat'));
    expect(source, contains('"voiceProcessingMode": voiceProcessingMode'));
    expect(source, contains('"platformManaged": voiceProcessingMode'));
    expect(source, contains('"acousticEchoCancellation": NSNull()'));
  });
}
