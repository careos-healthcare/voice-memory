import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../services/analytics/ffi_safety_monitor.dart';
import '../microphone_permission_environment.dart';
import 'audio_diag_log.dart';
import 'audio_level_monitor.dart';

enum NativeAudioFormat {
  wavPcm16('wav', 'wav'),
  aac('aac', 'm4a');

  const NativeAudioFormat(this.channelValue, this.fileExtension);

  final String channelValue;
  final String fileExtension;

  static NativeAudioFormat fromChannelValue(Object? value) {
    switch (value?.toString().toLowerCase()) {
      case 'aac':
      case 'm4a':
        return NativeAudioFormat.aac;
      default:
        return NativeAudioFormat.wavPcm16;
    }
  }
}

enum NativeAudioSessionMode {
  spokenAudio('spokenAudio'),
  measurement('measurement'),
  raw('raw');

  const NativeAudioSessionMode(this.channelValue);
  final String channelValue;
}

enum NativeAudioProcessingControl {
  platformDefault('default'),
  enabled('enabled'),
  disabled('disabled');

  const NativeAudioProcessingControl(this.channelValue);
  final String channelValue;

  static NativeAudioProcessingControl fromChannelValue(Object? value) {
    switch (value?.toString()) {
      case 'enabled':
        return NativeAudioProcessingControl.enabled;
      case 'disabled':
        return NativeAudioProcessingControl.disabled;
      default:
        return NativeAudioProcessingControl.platformDefault;
    }
  }
}

@immutable
class NativeAudioCaptureConfig {
  const NativeAudioCaptureConfig({
    this.format = NativeAudioFormat.wavPcm16,
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitDepth = 16,
    this.bufferDuration = const Duration(milliseconds: 20),
    this.sessionMode = NativeAudioSessionMode.spokenAudio,
    this.acousticEchoCancellation =
        NativeAudioProcessingControl.platformDefault,
    this.noiseSuppression = NativeAudioProcessingControl.platformDefault,
    this.automaticGainControl = NativeAudioProcessingControl.platformDefault,
  });

  final NativeAudioFormat format;
  final int sampleRate;
  final int channels;
  final int bitDepth;
  final Duration bufferDuration;
  final NativeAudioSessionMode sessionMode;
  final NativeAudioProcessingControl acousticEchoCancellation;
  final NativeAudioProcessingControl noiseSuppression;
  final NativeAudioProcessingControl automaticGainControl;

  /// Returns values within the common bounds accepted by both native backends.
  NativeAudioCaptureConfig normalized() => NativeAudioCaptureConfig(
    format: format,
    sampleRate: sampleRate.clamp(8000, 192000),
    channels: channels.clamp(1, 2),
    bitDepth: bitDepth.clamp(8, 32),
    bufferDuration: Duration(
      microseconds: bufferDuration.inMicroseconds.clamp(1000, 500000),
    ),
    sessionMode: sessionMode,
    acousticEchoCancellation: acousticEchoCancellation,
    noiseSuppression: noiseSuppression,
    automaticGainControl: automaticGainControl,
  );

  Map<String, Object> toMap() => <String, Object>{
    'format': format.channelValue,
    'sampleRate': sampleRate,
    'channels': channels,
    'bitDepth': bitDepth,
    'bufferDurationMs': bufferDuration.inMicroseconds / 1000,
    'sessionMode': sessionMode.channelValue,
    'acousticEchoCancellation': acousticEchoCancellation.channelValue,
    'noiseSuppression': noiseSuppression.channelValue,
    'automaticGainControl': automaticGainControl.channelValue,
  };

  NativeAudioCaptureConfig copyWith({
    NativeAudioFormat? format,
    int? sampleRate,
    int? channels,
    int? bitDepth,
    Duration? bufferDuration,
    NativeAudioSessionMode? sessionMode,
    NativeAudioProcessingControl? acousticEchoCancellation,
    NativeAudioProcessingControl? noiseSuppression,
    NativeAudioProcessingControl? automaticGainControl,
  }) {
    return NativeAudioCaptureConfig(
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      bitDepth: bitDepth ?? this.bitDepth,
      bufferDuration: bufferDuration ?? this.bufferDuration,
      sessionMode: sessionMode ?? this.sessionMode,
      acousticEchoCancellation:
          acousticEchoCancellation ?? this.acousticEchoCancellation,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      automaticGainControl: automaticGainControl ?? this.automaticGainControl,
    );
  }
}

@immutable
class NativeAudioProcessingMetadata {
  const NativeAudioProcessingMetadata({
    this.requestedAcousticEchoCancellation,
    this.requestedNoiseSuppression,
    this.requestedAutomaticGainControl,
    this.appliedAcousticEchoCancellation,
    this.appliedNoiseSuppression,
    this.appliedAutomaticGainControl,
    this.acousticEchoCancellationSupported,
    this.noiseSuppressionSupported,
    this.automaticGainControlSupported,
    this.acousticEchoCancellationEnabled,
    this.noiseSuppressionEnabled,
    this.automaticGainControlEnabled,
    this.voiceProcessingMode,
    this.platformManaged,
  });

  factory NativeAudioProcessingMetadata.fromMap(Map<Object?, Object?>? map) {
    final requested = map?['requested'];
    final applied = map?['applied'];
    final supported = map?['supported'];
    final enabled = map?['enabled'];
    final requestedMap = requested is Map<Object?, Object?> ? requested : null;
    final appliedMap = applied is Map<Object?, Object?> ? applied : null;
    final supportedMap = supported is Map<Object?, Object?> ? supported : null;
    final enabledMap = enabled is Map<Object?, Object?> ? enabled : null;
    bool? boolean(Map<Object?, Object?>? values, String key) =>
        values?[key] is bool ? values![key] as bool : null;
    NativeAudioProcessingControl? control(
      Map<Object?, Object?>? values,
      String key,
    ) => values?.containsKey(key) == true
        ? NativeAudioProcessingControl.fromChannelValue(values![key])
        : null;
    return NativeAudioProcessingMetadata(
      requestedAcousticEchoCancellation: control(
        requestedMap,
        'acousticEchoCancellation',
      ),
      requestedNoiseSuppression: control(requestedMap, 'noiseSuppression'),
      requestedAutomaticGainControl: control(
        requestedMap,
        'automaticGainControl',
      ),
      appliedAcousticEchoCancellation: control(
        appliedMap,
        'acousticEchoCancellation',
      ),
      appliedNoiseSuppression: control(appliedMap, 'noiseSuppression'),
      appliedAutomaticGainControl: control(appliedMap, 'automaticGainControl'),
      acousticEchoCancellationSupported: boolean(
        supportedMap,
        'acousticEchoCancellation',
      ),
      noiseSuppressionSupported: boolean(supportedMap, 'noiseSuppression'),
      automaticGainControlSupported: boolean(
        supportedMap,
        'automaticGainControl',
      ),
      acousticEchoCancellationEnabled: boolean(
        enabledMap,
        'acousticEchoCancellation',
      ),
      noiseSuppressionEnabled: boolean(enabledMap, 'noiseSuppression'),
      automaticGainControlEnabled: boolean(enabledMap, 'automaticGainControl'),
      voiceProcessingMode: map?['voiceProcessingMode'] is bool
          ? map!['voiceProcessingMode'] as bool
          : null,
      platformManaged: map?['platformManaged'] is bool
          ? map!['platformManaged'] as bool
          : null,
    );
  }

  final NativeAudioProcessingControl? requestedAcousticEchoCancellation;
  final NativeAudioProcessingControl? requestedNoiseSuppression;
  final NativeAudioProcessingControl? requestedAutomaticGainControl;
  final NativeAudioProcessingControl? appliedAcousticEchoCancellation;
  final NativeAudioProcessingControl? appliedNoiseSuppression;
  final NativeAudioProcessingControl? appliedAutomaticGainControl;
  final bool? acousticEchoCancellationSupported;
  final bool? noiseSuppressionSupported;
  final bool? automaticGainControlSupported;
  final bool? acousticEchoCancellationEnabled;
  final bool? noiseSuppressionEnabled;
  final bool? automaticGainControlEnabled;
  final bool? voiceProcessingMode;
  final bool? platformManaged;

  @override
  String toString() =>
      'NativeAudioProcessingMetadata('
      'requested=[$requestedAcousticEchoCancellation,'
      '$requestedNoiseSuppression,$requestedAutomaticGainControl], '
      'applied=[$appliedAcousticEchoCancellation,'
      '$appliedNoiseSuppression,$appliedAutomaticGainControl], '
      'supported=[$acousticEchoCancellationSupported,'
      '$noiseSuppressionSupported,$automaticGainControlSupported], '
      'enabled=[$acousticEchoCancellationEnabled,'
      '$noiseSuppressionEnabled,$automaticGainControlEnabled], '
      'voiceProcessingMode=$voiceProcessingMode, '
      'platformManaged=$platformManaged)';
}

@immutable
class NativeMicrophonePermission {
  const NativeMicrophonePermission({
    required this.status,
    required this.granted,
    required this.canRequest,
  });

  factory NativeMicrophonePermission.fromMap(Map<Object?, Object?>? map) {
    return NativeMicrophonePermission(
      status: map?['status']?.toString() ?? 'unknown',
      granted: map?['granted'] == true,
      canRequest: map?['canRequest'] == true,
    );
  }

  final String status;
  final bool granted;
  final bool canRequest;
}

@immutable
class NativeRecordingLevel {
  const NativeRecordingLevel({
    required this.currentDb,
    required this.peakDb,
    required this.maxDb,
    required this.avgDb,
  });

  factory NativeRecordingLevel.fromMap(Map<Object?, Object?>? map) {
    double value(String key) =>
        map?[key] is num ? (map![key] as num).toDouble() : -160;
    return NativeRecordingLevel(
      currentDb: value('currentDb'),
      peakDb: value('peakDb'),
      maxDb: value('maxDb'),
      avgDb: value('avgDb'),
    );
  }

  final double currentDb;
  final double peakDb;
  final double maxDb;
  final double avgDb;
}

@immutable
class NativeAudioStartResult {
  const NativeAudioStartResult({
    required this.path,
    this.format,
    this.sampleRate,
    this.channels,
    this.bitDepth,
    this.bufferDurationMs,
    this.sessionMode,
    this.audioSource,
    this.audioSessionId,
    this.inputPortName,
    this.inputPortType,
    this.processing = const NativeAudioProcessingMetadata(),
  });

  factory NativeAudioStartResult.fromMap(
    Map<Object?, Object?>? map, {
    required String fallbackPath,
  }) {
    return NativeAudioStartResult(
      path: map?['path']?.toString() ?? fallbackPath,
      format: map?['format']?.toString(),
      sampleRate: (map?['sampleRate'] as num?)?.toInt(),
      channels: (map?['channels'] as num?)?.toInt(),
      bitDepth: (map?['bitDepth'] as num?)?.toInt(),
      bufferDurationMs: (map?['bufferDurationMs'] as num?)?.toDouble(),
      sessionMode: map?['sessionMode']?.toString(),
      audioSource: map?['audioSource']?.toString(),
      audioSessionId: (map?['audioSessionId'] as num?)?.toInt(),
      inputPortName: map?['inputPortName']?.toString(),
      inputPortType: map?['inputPortType']?.toString(),
      processing: NativeAudioProcessingMetadata.fromMap(
        map?['processing'] is Map<Object?, Object?>
            ? map!['processing'] as Map<Object?, Object?>
            : null,
      ),
    );
  }

  final String path;
  final String? format;
  final int? sampleRate;
  final int? channels;
  final int? bitDepth;
  final double? bufferDurationMs;
  final String? sessionMode;
  final String? audioSource;
  final int? audioSessionId;
  final String? inputPortName;
  final String? inputPortType;
  final NativeAudioProcessingMetadata processing;
}

@immutable
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
    this.sampleRate,
    this.channels,
    this.bitDepth,
    this.bufferBytes,
    this.bufferDurationMs,
    this.sessionMode,
    this.audioSource,
    this.audioSessionId,
    this.inputPortName,
    this.inputPortType,
    this.processing = const NativeAudioProcessingMetadata(),
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
      sampleRate: (map['sampleRate'] as num?)?.toInt(),
      channels: (map['channels'] as num?)?.toInt(),
      bitDepth: (map['bitDepth'] as num?)?.toInt(),
      bufferBytes: (map['bufferBytes'] as num?)?.toInt(),
      bufferDurationMs: (map['bufferDurationMs'] as num?)?.toDouble(),
      sessionMode: map['sessionMode']?.toString(),
      audioSource: map['audioSource']?.toString(),
      audioSessionId: (map['audioSessionId'] as num?)?.toInt(),
      inputPortName: map['inputPortName']?.toString(),
      inputPortType: map['inputPortType']?.toString(),
      processing: NativeAudioProcessingMetadata.fromMap(
        map['processing'] is Map<Object?, Object?>
            ? map['processing'] as Map<Object?, Object?>
            : null,
      ),
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
  final int? sampleRate;
  final int? channels;
  final int? bitDepth;
  final int? bufferBytes;
  final double? bufferDurationMs;
  final String? sessionMode;
  final String? audioSource;
  final int? audioSessionId;
  final String? inputPortName;
  final String? inputPortType;
  final NativeAudioProcessingMetadata processing;

  AudioLevelSummary toAudioLevelSummary() => AudioLevelSummary(
    minDb: minDb,
    maxDb: maxDb,
    avgDb: avgDb,
    sampleCount: durationMs > 0 ? 1 : 0,
    likelySilent: likelySilent,
  );
}

class NativeRecorderException implements Exception {
  const NativeRecorderException({
    required this.step,
    required this.reason,
    this.code,
    this.format,
  });

  factory NativeRecorderException.fromPlatform(PlatformException exception) {
    final details = exception.details;
    return NativeRecorderException(
      step: details is Map
          ? details['step']?.toString() ?? 'unknown'
          : 'unknown',
      reason: exception.message ?? exception.toString(),
      code: exception.code,
      format: details is Map ? details['format']?.toString() : null,
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

abstract interface class NativeAudioRecorderPlatform {
  Future<bool> isAvailable();
  Future<NativeMicrophonePermission> microphonePermission();
  Future<NativeMicrophonePermission> requestMicrophonePermission();
  Future<NativeAudioStartResult> start(
    String path,
    NativeAudioCaptureConfig config,
  );
  Future<NativeRecordingStopResult> stop();
  Future<NativeRecordingLevel> currentLevel();
  Future<void> dispose();
}

class MethodChannelNativeAudioRecorderPlatform
    implements NativeAudioRecorderPlatform {
  MethodChannelNativeAudioRecorderPlatform({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(NativeAudioRecorder.channelName);

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async =>
      await _channel.invokeMethod<bool>('isNativeRecorderAvailable') ?? false;

  @override
  Future<NativeMicrophonePermission> microphonePermission() async {
    final value = await _channel.invokeMethod<Object?>(
      'nativeMicrophonePermission',
    );
    return NativeMicrophonePermission.fromMap(
      value is Map<Object?, Object?> ? value : null,
    );
  }

  @override
  Future<NativeMicrophonePermission> requestMicrophonePermission() async {
    final value = await _channel.invokeMethod<Object?>(
      'requestNativeMicrophonePermission',
    );
    return NativeMicrophonePermission.fromMap(
      value is Map<Object?, Object?> ? value : null,
    );
  }

  @override
  Future<NativeAudioStartResult> start(
    String path,
    NativeAudioCaptureConfig config,
  ) async {
    try {
      final normalized = config.normalized();
      final value = await _channel.invokeMethod<Object?>(
        'startNativeRecording',
        <String, Object>{'path': path, 'config': normalized.toMap()},
      );
      return NativeAudioStartResult.fromMap(
        value is Map<Object?, Object?> ? value : null,
        fallbackPath: path,
      );
    } on PlatformException catch (exception) {
      NativeRecorderException.logAndThrow(exception);
    }
  }

  @override
  Future<NativeRecordingStopResult> stop() async {
    final value = await _channel.invokeMethod<Object?>('stopNativeRecording');
    if (value is! Map<Object?, Object?>) {
      throw PlatformException(
        code: 'native_recorder_stop',
        message: 'Unexpected stopNativeRecording response',
      );
    }
    return NativeRecordingStopResult.fromMap(value);
  }

  @override
  Future<NativeRecordingLevel> currentLevel() async {
    final value = await _channel.invokeMethod<Object?>('currentNativeLevel');
    return NativeRecordingLevel.fromMap(
      value is Map<Object?, Object?> ? value : null,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod<void>('disposeNativeRecorder');
    } on MissingPluginException {
      // Tests and unsupported runtimes do not install the native recorder
      // channel. Disposal is best-effort when no native state can exist.
    } on FlutterError {
      // Pure unit tests may dispose AppServices before a Flutter binding has
      // been initialized, so there is no binary messenger to notify.
    }
  }
}

/// Capture facade consumed by [RecordingService].
///
/// This boundary is intentionally above the method-channel adapter so tests
/// can replace native selection and capture behavior per service instance.
abstract interface class AudioRecorderPlatform {
  NativeAudioCaptureConfig get config;

  Future<bool> shouldUseOnDevice();
  Future<NativeMicrophonePermission> microphonePermission();
  Future<NativeMicrophonePermission> requestMicrophonePermission();
  Future<String> startRecording(
    String path, {
    NativeAudioCaptureConfig? config,
  });
  Future<NativeAudioStartResult> start(
    String path, {
    NativeAudioCaptureConfig? config,
  });
  Future<NativeRecordingStopResult> stopRecording();
  Future<NativeRecordingLevel> currentLevel();
  Future<void> dispose();
}

class NativeAudioRecorder implements AudioRecorderPlatform {
  NativeAudioRecorder({
    NativeAudioRecorderPlatform? platform,
    NativeAudioCaptureConfig? config,
  }) : platform = platform ?? MethodChannelNativeAudioRecorderPlatform(),
       config = config ?? _configuredCaptureConfig();

  static const channelName = 'archive_me/native_audio_recorder';
  static const iosEnabled = bool.fromEnvironment(
    'ARCHIVEME_USE_NATIVE_IOS_RECORDER',
    defaultValue: true,
  );
  static const androidEnabled = bool.fromEnvironment(
    'ARCHIVEME_USE_NATIVE_ANDROID_RECORDER',
    defaultValue: true,
  );
  static const _legacyIosFormat = String.fromEnvironment(
    'ARCHIVEME_IOS_RECORDING_FORMAT',
    defaultValue: '',
  );

  final NativeAudioRecorderPlatform platform;
  @override
  final NativeAudioCaptureConfig config;
  bool _disposed = false;
  bool _recording = false;
  FFIResourceLease? _recordingLease;

  static NativeAudioCaptureConfig _configuredCaptureConfig() {
    final format =
        !kIsWeb &&
            Platform.isIOS &&
            (_legacyIosFormat.toLowerCase() == 'aac' ||
                _legacyIosFormat.toLowerCase() == 'm4a')
        ? NativeAudioFormat.aac
        : NativeAudioFormat.wavPcm16;
    return NativeAudioCaptureConfig(format: format);
  }

  @override
  Future<bool> shouldUseOnDevice({
    bool? enabledOverride,
    Future<bool> Function()? isIosPhysicalDevice,
  }) async {
    if (kIsWeb) return false;
    final isIos = Platform.isIOS;
    final isAndroid = Platform.isAndroid;
    if (!isIos && !isAndroid) return false;
    final enabled =
        enabledOverride ??
        (isIos ? NativeAudioRecorder.iosEnabled : androidEnabled);
    if (!enabled) return false;
    if (isIos) {
      final physical = isIosPhysicalDevice != null
          ? await isIosPhysicalDevice()
          : await MicrophonePermissionEnvironment.isIosPhysicalDevice();
      if (!physical) return false;
    }
    return platform.isAvailable();
  }

  @override
  Future<NativeMicrophonePermission> microphonePermission() =>
      platform.microphonePermission();

  @override
  Future<NativeMicrophonePermission> requestMicrophonePermission() =>
      platform.requestMicrophonePermission();

  @override
  Future<String> startRecording(
    String path, {
    NativeAudioCaptureConfig? config,
  }) async {
    _ensureNotRecording();
    _disposed = false;
    final result = await platform.start(
      path,
      (config ?? this.config).normalized(),
    );
    _recording = true;
    _recordingLease = FFISafetyMonitor.installed?.acquire(
      FFIResourceKind.nativeAudioRecorder,
      owner: 'native-audio-recorder',
    );
    return result.path;
  }

  @override
  Future<NativeAudioStartResult> start(
    String path, {
    NativeAudioCaptureConfig? config,
  }) async {
    _ensureNotRecording();
    _disposed = false;
    final result = await platform.start(
      path,
      (config ?? this.config).normalized(),
    );
    _recording = true;
    _recordingLease = FFISafetyMonitor.installed?.acquire(
      FFIResourceKind.nativeAudioRecorder,
      owner: 'native-audio-recorder',
    );
    return result;
  }

  @override
  Future<NativeRecordingStopResult> stopRecording() async {
    final result = await platform.stop();
    _recording = false;
    _recordingLease?.release();
    _recordingLease = null;
    return result;
  }

  @override
  Future<NativeRecordingLevel> currentLevel() => platform.currentLevel();
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await platform.dispose();
    } finally {
      _recording = false;
      _recordingLease?.release();
      _recordingLease = null;
    }
  }

  void _ensureNotRecording() {
    if (_recording) {
      throw StateError('Native audio recording is already active.');
    }
  }
}
