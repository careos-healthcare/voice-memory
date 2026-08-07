import 'dart:io';

import 'package:flutter/foundation.dart';

import '../features/voice_capture/audio/ios_native_recorder.dart';
import '../features/voice_capture/audio/ios_native_recorder_config.dart';

/// Resolves capture file paths for plugin and native iOS recorders.
class RecordingPathResolver {
  RecordingPathResolver({this.useNativeRecorderOverride});

  final bool? useNativeRecorderOverride;

  Future<bool> shouldUseNativeRecorder() async {
    final override = useNativeRecorderOverride;
    if (override != null) return override;
    return IosNativeRecorder.shouldUseOnDevice();
  }

  String testRecordingPath({
    required bool native,
    IosRecordingFormat format = IosRecordingFormat.wav,
  }) {
    if (!native) {
      return '${Directory.systemTemp.path}/vm_rec_test.m4a';
    }
    final ext = IosNativeRecorderConfig.fileExtensionFor(format);
    return '${Directory.systemTemp.path}/vm_rec_test_native.$ext';
  }

  Future<String> productionRecordingPath(String directoryPath) async {
    final format = await IosNativeRecorderConfig.recordingFormatForDevice();
    final ext = IosNativeRecorderConfig.fileExtensionFor(format);
    return '$directoryPath/vm_rec_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }

  String retryRecordingPath(String directoryPath) {
    return '$directoryPath/vm_rec_retry_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  /// Applies native test-platform path override when injected in widget tests.
  Future<String> resolveTestNativeStartPath(String candidatePath) async {
    if (IosNativeRecorder.hasInjectedTestPlatform) {
      return IosNativeRecorder.startRecording(candidatePath);
    }
    return candidatePath;
  }
}
