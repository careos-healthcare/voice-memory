import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_lifecycle_policy.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_pipeline_log.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/native_audio_lifecycle_bridge.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Watches native audio focus / interruption events for live voice sessions.
class LiveAudioFocusGateway {
  LiveAudioFocusGateway({
    required this._captureService,
    Future<AudioSession> Function()? resolveSession,
    this._interruptionEventsForTest,
    NativeAudioLifecycleBridge? nativeLifecycleBridge,
    AppLifecycleState initialAppLifecycle = AppLifecycleState.resumed,
  }) : _resolveSession = resolveSession ?? (() => AudioSession.instance),
       _nativeLifecycleBridgeOverride = nativeLifecycleBridge,
       _appLifecycleState = initialAppLifecycle;

  final LiveVoiceCaptureService _captureService;
  final Future<AudioSession> Function() _resolveSession;
  final Stream<AudioInterruptionEvent>? _interruptionEventsForTest;
  final NativeAudioLifecycleBridge? _nativeLifecycleBridgeOverride;

  StreamSubscription<AudioInterruptionEvent>? _interruptSubscription;
  NativeAudioLifecycleBridge? _nativeLifecycleBridge;
  AppLifecycleState _appLifecycleState;
  var _deferredFocusResume = false;
  var _disposed = false;

  AppLifecycleState get appLifecycleState => _appLifecycleState;
  bool get deferredFocusResume => _deferredFocusResume;

  /// Requests hardware audio focus configured for real-time conversation.
  Future<void> initializeAndRequestFocus() async {
    final session = await _resolveSession();

    await session.configure(liveVoiceAudioSessionConfiguration);
    await reactivateFocus();

    final stream =
        _interruptionEventsForTest ?? session.interruptionEventStream;
    _interruptSubscription = stream.listen(_handleInterruption);

    if (!kIsWeb && Platform.isIOS) {
      _nativeLifecycleBridge =
          _nativeLifecycleBridgeOverride ??
          NativeAudioLifecycleBridge(_captureService);
    }
  }

  void updateAppLifecycle(AppLifecycleState state) {
    _appLifecycleState = state;
    if (_disposed) return;

    if (LiveVoiceLifecyclePolicy.isForegroundForCapture(state) &&
        _deferredFocusResume) {
      unawaited(resumeCaptureIfPossible());
    }
  }

  /// Re-requests native audio focus before restarting mic capture.
  Future<void> reactivateFocus() async {
    if (_disposed) return;

    final session = await _resolveSession();
    await session.setActive(true);
    LiveAudioPipelineLog.audioFocusReactivated();
  }

  /// Resumes capture after focus/lifecycle preconditions are satisfied.
  Future<void> resumeCaptureIfPossible() async {
    if (_disposed || !_captureService.isPausedByAudioFocus) return;

    if (!LiveVoiceLifecyclePolicy.isForegroundForCapture(_appLifecycleState)) {
      _deferredFocusResume = true;
      LiveAudioPipelineLog.audioFocusResumeDeferred(reason: 'app_background');
      return;
    }

    _deferredFocusResume = false;
    await reactivateFocus();
    await _captureService.resumeLiveCaptureIfActive();
  }

  @visibleForTesting
  static const liveVoiceAudioSessionConfiguration = AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
    avAudioSessionMode: AVAudioSessionMode.voiceChat,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.speech,
      usage: AndroidAudioUsage.voiceCommunication,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientExclusive,
    androidWillPauseWhenDucked: true,
  );

  @visibleForTesting
  static bool shouldResumeAfterInterruption(AudioInterruptionEvent event) {
    if (event.begin) return false;
    return event.type == AudioInterruptionType.pause ||
        event.type == AudioInterruptionType.duck;
  }

  Future<void> _handleInterruption(AudioInterruptionEvent event) async {
    if (event.begin) {
      AppLogger.debug(
        'ARCHIVEME_LIVE: Native audio interruption began (e.g., call received)',
      );
      _deferredFocusResume = false;
      await _captureService.pauseMicrophoneCaptureForFocus();
      return;
    }

    AppLogger.debug('ARCHIVEME_LIVE: Native audio interruption ended');
    if (shouldResumeAfterInterruption(event)) {
      await resumeCaptureIfPossible();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _interruptSubscription?.cancel();
    _interruptSubscription = null;
    if (_nativeLifecycleBridgeOverride == null) {
      await _nativeLifecycleBridge?.dispose();
    }
    _nativeLifecycleBridge = null;
    _deferredFocusResume = false;
    try {
      final session = await _resolveSession();
      await session.setActive(false);
    } catch (error, stackTrace) {
      LiveAudioPipelineLog.failure('audio_focus_dispose', error);
    }
  }
}