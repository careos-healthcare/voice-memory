import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_pipeline_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Listens for native AVAudioSession signals and pauses/resumes live capture.
class NativeAudioLifecycleBridge {
  NativeAudioLifecycleBridge(this._service, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleNativeEvent);
  }

  static const channelName = 'com.archiveme.live/audio_lifecycle';

  final LiveVoiceCaptureService _service;
  final MethodChannel _channel;

  @visibleForTesting
  Future<void> handleNativeEvent(MethodCall call) => _handleNativeEvent(call);

  /// Control Center and Quick Settings enter here. The native
  /// `LiveAudioLifecycleBridge` activates the record session, then live
  /// capture starts.
  Future<void> startRecordingSequence() async {
    try {
      await _channel.invokeMethod<void>('startRecordingSequence');
    } on MissingPluginException catch (error, stackTrace) {
      AppLogger.debug(
        'Live audio record session activation skipped',
        error: error,
        stackTrace: stackTrace,
      );
    } on PlatformException catch (error, stackTrace) {
      AppLogger.debug(
        'Live audio record session activation skipped',
        error: error,
        stackTrace: stackTrace,
      );
    }
    await _service.start();
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    switch (call.method) {
      case 'onAudioInterruptionBegan':
        await _service.pauseMicrophoneCaptureForFocus();
      case 'onAudioInterruptionEnded':
        await _service.resumeLiveCaptureIfActive();
      case 'onAudioRouteChanged':
        final args = call.arguments;
        final map = args is Map ? Map<Object?, Object?>.from(args) : null;
        LiveAudioPipelineLog.diagnostics(
          'ios audio route changed reason=${map?['reason']} '
          'inputs=${map?['inputs']} outputs=${map?['outputs']}',
        );
    }
  }
}
