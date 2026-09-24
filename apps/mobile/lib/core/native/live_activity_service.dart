import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sends recording waveform and pause state to the iOS Live Activity.
///
/// Android and tests skip the channel. The native side owns
/// `Activity.request`, debounced `activity.update`, and `activity.end`.
class LiveActivityService {
  LiveActivityService({
    MethodChannel? channel,
    DateTime Function()? clock,
    bool? enabled,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _clock = clock ?? DateTime.now,
       _enabled = enabled ?? (!kIsWeb && Platform.isIOS);

  static const channelName = 'com.archiveme/live_activity';
  static const startMethod = 'startLiveActivity';
  static const updateMethod = 'updateLiveActivity';
  static const endMethod = 'endLiveActivity';
  static const togglePauseMethod = 'togglePause';
  static const stopMethod = 'stopRecording';
  static const barCount = 8;
  static const throttle = Duration(milliseconds: 500);

  static const double _floorDb = -55;
  static const double _ceilingDb = -8;

  final MethodChannel _channel;
  final DateTime Function() _clock;
  final bool _enabled;

  final List<double> _levels = List<double>.filled(barCount, 0);
  DateTime? _lastSent;
  var _sessionOpen = false;
  var _paused = false;
  Future<void> Function()? _onTogglePause;
  Future<void> Function()? _onStop;

  bool get isSessionOpen => _sessionOpen;

  /// Eight normalized levels currently queued for the island waveform.
  List<double> get levels => List<double>.unmodifiable(_levels);

  /// Island buttons call back into the recording session.
  void bindControls({
    required Future<void> Function() onTogglePause,
    required Future<void> Function() onStop,
  }) {
    _onTogglePause = onTogglePause;
    _onStop = onStop;
    if (!_enabled) return;
    _channel.setMethodCallHandler(_onNativeCall);
  }

  /// Opens a Live Activity when capture begins.
  Future<void> start({required String recordingId}) async {
    _sessionOpen = true;
    _paused = false;
    _lastSent = null;
    for (var index = 0; index < barCount; index++) {
      _levels[index] = 0;
    }
    await _invoke(startMethod, <String, Object>{
      'recordingId': recordingId,
      'startDate': _clock().millisecondsSinceEpoch,
    });
  }

  /// Opens a Live Activity for [recordingId].
  Future<void> startLiveActivity(String recordingId) =>
      start(recordingId: recordingId);

  /// Maps one raw decibel sample into the 8-bar waveform.
  ///
  /// Samples closer than [throttle] update the bars locally and wait.
  void pushDecibel(double decibel) {
    if (!_sessionOpen || _paused) return;
    _pushNormalized(normalizeDecibel(decibel));
  }

  /// Same waveform path when the caller already has a 0...1 level.
  void pushNormalized(double level) {
    if (!_sessionOpen || _paused) return;
    _pushNormalized(level.clamp(0.0, 1.0));
  }

  Future<void> setPaused({required bool isPaused}) async {
    _paused = isPaused;
    if (!_sessionOpen) return;
    _lastSent = _clock();
    await update(isPaused: isPaused);
  }

  Future<void> update({required bool isPaused}) async {
    await updateLiveActivity(isPaused: isPaused, decibelLevels: _levels);
  }

  /// Pushes pause state and an 8-bar waveform to the Live Activity.
  Future<void> updateLiveActivity({
    required bool isPaused,
    required List<double> decibelLevels,
  }) async {
    _paused = isPaused;
    for (var index = 0; index < barCount; index++) {
      final level = index < decibelLevels.length ? decibelLevels[index] : 0.0;
      _levels[index] = level.clamp(0.0, 1.0);
    }
    if (!_sessionOpen) return;
    await _invoke(updateMethod, <String, Object>{
      'isPaused': isPaused,
      'decibels': List<double>.from(_levels),
    });
  }

  Future<void> endLiveActivity() => end();

  /// Dismisses the Live Activity when capture stops or fails.
  Future<void> end() async {
    final wasOpen = _sessionOpen;
    _sessionOpen = false;
    _paused = false;
    _lastSent = null;
    if (!wasOpen) return;
    await _invoke(endMethod, null);
  }

  /// Maps `record` package decibels into 0.0...1.0.
  static double normalizeDecibel(double decibel) {
    if (!decibel.isFinite) return 0;
    const span = _ceilingDb - _floorDb;
    final normalized = (decibel - _floorDb) / span;
    if (normalized <= 0) return 0;
    if (normalized >= 1) return 1;
    return normalized;
  }

  Future<void> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case togglePauseMethod:
        await _onTogglePause?.call();
      case stopMethod:
        await _onStop?.call();
      default:
        break;
    }
  }

  void _pushNormalized(double level) {
    for (var index = 0; index < barCount - 1; index++) {
      _levels[index] = _levels[index + 1];
    }
    _levels[barCount - 1] = level;
    final now = _clock();
    final previous = _lastSent;
    if (previous != null && now.difference(previous) < throttle) return;
    _lastSent = now;
    unawaited(update(isPaused: _paused));
  }

  Future<void> _invoke(String method, Object? arguments) async {
    if (!_enabled) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      return;
    } on PlatformException catch (error, stackTrace) {
      AppLogger.debug(
        'Live Activity $method skipped',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
