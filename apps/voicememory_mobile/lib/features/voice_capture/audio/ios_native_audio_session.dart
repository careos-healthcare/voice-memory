import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_diag_log.dart';

enum IosCaptureAudioMode {
  spokenAudio('spokenAudio'),
  measurement('measurement');

  const IosCaptureAudioMode(this.value);
  final String value;
}

class IosAudioSessionSnapshot {
  const IosAudioSessionSnapshot({
    required this.configured,
    required this.category,
    required this.mode,
    this.sampleRate,
    this.inputChannels,
    this.outputVolume,
  });

  factory IosAudioSessionSnapshot.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const IosAudioSessionSnapshot(
        configured: false,
        category: 'playAndRecord',
        mode: 'unknown',
      );
    }
    return IosAudioSessionSnapshot(
      configured: map['configured'] == true,
      category: map['category']?.toString() ?? 'playAndRecord',
      mode: map['mode']?.toString() ?? 'unknown',
      sampleRate: _asDouble(map['sampleRate']),
      inputChannels: _asInt(map['inputChannels']),
      outputVolume: _asDouble(map['outputVolume']),
    );
  }

  final bool configured;
  final String category;
  final String mode;
  final double? sampleRate;
  final int? inputChannels;
  final double? outputVolume;

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    return null;
  }
}

typedef IosNativeAudioSessionInvoker = Future<IosAudioSessionSnapshot?> Function(
  IosCaptureAudioMode mode,
);

/// Native AVAudioSession configuration via AppDelegate method channel.
abstract class IosNativeAudioSession {
  IosNativeAudioSession._();

  static const channelName = 'archive_me/ios_capture_audio';

  @visibleForTesting
  static IosNativeAudioSessionInvoker? testInvoker;

  static Future<IosAudioSessionSnapshot?> configureForCapture({
    IosCaptureAudioMode mode = IosCaptureAudioMode.spokenAudio,
  }) async {
    final testInvoker = IosNativeAudioSession.testInvoker;
    if (testInvoker != null) {
      final snapshot = await testInvoker(mode);
      AudioDiagLog.iosAudioSession(
        configured: snapshot?.configured ?? false,
        category: snapshot?.category ?? 'playAndRecord',
        mode: snapshot?.mode ?? mode.value,
        sampleRate: snapshot?.sampleRate,
        inputChannels: snapshot?.inputChannels,
        outputVolume: snapshot?.outputVolume,
      );
      return snapshot;
    }

    if (kIsWeb || !Platform.isIOS) return null;

    try {
      final result = await const MethodChannel(channelName).invokeMethod<Object?>(
        'configureCaptureSession',
        {'mode': mode.value},
      );
      final snapshot = IosAudioSessionSnapshot.fromMap(
        result is Map<Object?, Object?> ? result : null,
      );
      AudioDiagLog.iosAudioSession(
        configured: snapshot.configured,
        category: snapshot.category,
        mode: snapshot.mode,
        sampleRate: snapshot.sampleRate,
        inputChannels: snapshot.inputChannels,
        outputVolume: snapshot.outputVolume,
      );
      return snapshot;
    } on PlatformException catch (e) {
      AudioDiagLog.iosAudioSession(
        configured: false,
        category: 'playAndRecord',
        mode: mode.value,
        detail: e.message ?? e.code,
      );
      return null;
    } catch (e) {
      AudioDiagLog.iosAudioSession(
        configured: false,
        category: 'playAndRecord',
        mode: mode.value,
        detail: e.toString(),
      );
      return null;
    }
  }
}
