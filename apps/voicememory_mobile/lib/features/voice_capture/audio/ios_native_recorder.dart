import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../microphone_permission_environment.dart';
import 'audio_diag_log.dart';
import 'audio_level_monitor.dart';
import 'ios_native_recorder_config.dart';

/// Thrown when native AVAudioRecorder startup fails on iOS.
class NativeRecorderException implements Exception {
  const NativeRecorderException({
    required this.step,
    required this.reason,
    this.code,
    this.format,
  });

  factory NativeRecorderException.fromPlatform(PlatformException exception) {
    var step = 'unknown';
    String? format;
    final details = exception.details;
    if (details is Map) {
      step = details['step']?.toString() ?? step;
      format = details['format']?.toString();
    }
    return NativeRecorderException(
      step: step,
      reason: exception.message ?? exception.toString(),
      code: exception.code,
      format: format,
    );
  }

  final String step;
  final String reason;
  final String? code;
  final String? format;

  @override
  String toString() =>
      'NativeRecorderException(step=$step, reason=$reason, format=$format)';

  static Never logAndThrow(PlatformException exception) {
    final parsed = NativeRecorderException.fromPlatform(exception);
    AudioDiagLog.nativeRecorderFailed(
      step: parsed.step,
      reason: parsed.reason,
      format: parsed.format,
    );
    throw parsed;
  }
}

class NativeRecordingLevel {
  const NativeRecordingLevel({
    required this.currentDb,
    required this.peakDb,
    required this.maxDb,
    required this.avgDb,
  });

  factory NativeRecordingLevel.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const NativeRecordingLevel(
        currentDb: -160,
        peakDb: -160,
        maxDb: -160,
        avgDb: -160,
      );
    }
    return NativeRecordingLevel(
      currentDb: _asDouble(map['currentDb']) ?? -160,
      peakDb: _asDouble(map['peakDb']) ?? -160,
      maxDb: _asDouble(map['maxDb']) ?? -160,
      avgDb: _asDouble(map['avgDb']) ?? -160,
    );
  }

  final double currentDb;
  final double peakDb;
  final double maxDb;
  final double avgDb;

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }
}

class NativeMicrophonePermission {
  const NativeMicrophonePermission({
    required this.status,
    required this.granted,
    required this.canRequest,
  });

  factory NativeMicrophonePermission.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const NativeMicrophonePermission(
        status: 'unknown',
        granted: false,
        canRequest: false,
      );
    }
    return NativeMicrophonePermission(
      status: map['status']?.toString() ?? 'unknown',
      granted: map['granted'] == true,
      canRequest: map['canRequest'] == true,
    );
  }

  final String status;
  final bool granted;
  final bool canRequest;
}

class NativeRecordingStopResult {
  const NativeRecordingStopResult({
    required this.path,
    required this.bytes,
    required this.durationMs,
    required this.minDb,
    required this.maxDb,
    required this.avgDb,
    required this.likelySilent,
    this.format,
    this.inputPortName,
    this.inputPortType,
  });

  factory NativeRecordingStopResult.fromMap(Map<Object?, Object?> map) {
    return NativeRecordingStopResult(
      path: map['path']?.toString() ?? '',
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      minDb: (map['minDb'] as num?)?.toDouble() ?? -160,
      maxDb: (map['maxDb'] as num?)?.toDouble() ?? -160,
      avgDb: (map['avgDb'] as num?)?.toDouble() ?? -160,
      likelySilent: map['likelySilent'] == true,
      format: map['format']?.toString(),
      inputPortName: map['inputPortName']?.toString(),
      inputPortType: map['inputPortType']?.toString(),
    );
  }

  final String path;
  final int bytes;
  final int durationMs;
  final double minDb;
  final double maxDb;
  final double avgDb;
  final bool likelySilent;
  final String? format;
  final String? inputPortName;
  final String? inputPortType;

  AudioLevelSummary toAudioLevelSummary() {
    return AudioLevelSummary(
      minDb: minDb,
      maxDb: maxDb,
      avgDb: avgDb,
      sampleCount: durationMs > 0 ? 1 : 0,
      likelySilent: likelySilent,
    );
  }
}

abstract class IosNativeRecorderPlatform {
  Future<bool> isNativeRecorderAvailable();
  Future<NativeMicrophonePermission> nativeMicrophonePermission();
  Future<NativeMicrophonePermission> requestNativeMicrophonePermission();
  Future<String> startNativeRecording(
    String path, {
    required IosRecordingFormat format,
  });
  Future<NativeRecordingStopResult> stopNativeRecording();
  Future<NativeRecordingLevel> currentNativeLevel();
}

class MethodChannelIosNativeRecorderPlatform
    implements IosNativeRecorderPlatform {
  MethodChannelIosNativeRecorderPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(IosNativeRecorder.channelName);

  final MethodChannel _channel;

  @override
  Future<bool> isNativeRecorderAvailable() async {
    final result = await _channel.invokeMethod<bool>(
      'isNativeRecorderAvailable',
    );
    return result ?? false;
  }

  @override
  Future<NativeMicrophonePermission> nativeMicrophonePermission() async {
    final result = await _channel.invokeMethod<Object?>(
      'nativeMicrophonePermission',
    );
    if (result is Map) {
      return NativeMicrophonePermission.fromMap(result);
    }
    return NativeMicrophonePermission.fromMap(null);
  }

  @override
  Future<NativeMicrophonePermission> requestNativeMicrophonePermission() async {
    final result = await _channel.invokeMethod<Object?>(
      'requestNativeMicrophonePermission',
    );
    if (result is Map) {
      return NativeMicrophonePermission.fromMap(result);
    }
    return const NativeMicrophonePermission(
      status: 'denied',
      granted: false,
      canRequest: false,
    );
  }

  @override
  Future<String> startNativeRecording(
    String path, {
    required IosRecordingFormat format,
  }) async {
    try {
      final result = await _channel.invokeMethod<Object?>(
        'startNativeRecording',
        {
          'path': path,
          'format': IosNativeRecorderConfig.channelFormatValue(format),
        },
      );
      if (result is Map && result['path'] is String) {
        return result['path'] as String;
      }
      return path;
    } on PlatformException catch (exception) {
      NativeRecorderException.logAndThrow(exception);
    }
  }

  @override
  Future<NativeRecordingStopResult> stopNativeRecording() async {
    final result = await _channel.invokeMethod<Object?>('stopNativeRecording');
    if (result is! Map) {
      throw PlatformException(
        code: 'native_recorder_stop',
        message: 'Unexpected stopNativeRecording response',
      );
    }
    return NativeRecordingStopResult.fromMap(result);
  }

  @override
  Future<NativeRecordingLevel> currentNativeLevel() async {
    final result = await _channel.invokeMethod<Object?>('currentNativeLevel');
    if (result is Map) {
      return NativeRecordingLevel.fromMap(result);
    }
    return NativeRecordingLevel.fromMap(null);
  }
}

/// Native AVAudioRecorder bridge for physical iOS capture.
abstract class IosNativeRecorder {
  IosNativeRecorder._();

  static const channelName = 'archive_me/ios_native_recorder';

  static bool get hasInjectedTestPlatform => testPlatform != null;

  @visibleForTesting
  static IosNativeRecorderPlatform? testPlatform;

  @visibleForTesting
  static bool? platformIsIosOverride;

  static bool get _isIosPlatform =>
      platformIsIosOverride ?? (!kIsWeb && Platform.isIOS);

  static IosNativeRecorderPlatform get _platform =>
      testPlatform ?? MethodChannelIosNativeRecorderPlatform();

  static Future<bool> shouldUseOnDevice({
    bool? enabledOverride,
    Future<bool> Function()? isPhysicalDevice,
  }) async {
    final enabled = enabledOverride ?? IosNativeRecorderConfig.enabled;
    if (!enabled) return false;
    if (!_isIosPlatform) return false;
    final isPhysical = isPhysicalDevice != null
        ? await isPhysicalDevice()
        : await MicrophonePermissionEnvironment.isIosPhysicalDevice();
    if (!isPhysical) return false;
    return _platform.isNativeRecorderAvailable();
  }

  static Future<bool> isAvailable() => _platform.isNativeRecorderAvailable();

  static Future<NativeMicrophonePermission> microphonePermission() =>
      _platform.nativeMicrophonePermission();

  static Future<NativeMicrophonePermission> requestMicrophonePermission() =>
      _platform.requestNativeMicrophonePermission();

  static Future<void> ensureMicrophonePermission() async {
    var permission = await microphonePermission();
    debugPrint(
      'ARCHIVEME_NATIVE_MIC_PERMISSION status=${permission.status} '
      'granted=${permission.granted}',
    );
    if (permission.granted) return;
    if (permission.canRequest) {
      permission = await requestMicrophonePermission();
      debugPrint(
        'ARCHIVEME_NATIVE_MIC_PERMISSION status=${permission.status} '
        'granted=${permission.granted} after_request=true',
      );
    }
    if (!permission.granted) {
      throw NativeRecorderException(
        step: 'microphone_permission_denied',
        reason: 'Native microphone permission is ${permission.status}',
      );
    }
  }

  static Future<String> startRecording(
    String path, {
    IosRecordingFormat? format,
  }) async {
    final resolvedFormat =
        format ?? await IosNativeRecorderConfig.recordingFormatForDevice();
    if (testPlatform == null) {
      await ensureMicrophonePermission();
    }
    return _platform.startNativeRecording(path, format: resolvedFormat);
  }

  static Future<NativeRecordingStopResult> stopRecording() =>
      _platform.stopNativeRecording();

  static Future<NativeRecordingLevel> currentLevel() =>
      _platform.currentNativeLevel();
}
