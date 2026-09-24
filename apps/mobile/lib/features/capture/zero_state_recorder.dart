import 'dart:async';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// How the record surface presents itself before speech starts.
enum ZeroStateRecorderMode { micOnly, oneLineMic, quoteFirst }

/// Direct-record context that used to arrive as a web query string.
class DirectRecordRequest {
  const DirectRecordRequest({
    this.source,
    this.quote,
    this.loopId,
    this.entryId,
    this.autoStart = true,
  });

  factory DirectRecordRequest.fromUri(Uri uri) {
    final auto = uri.queryParameters['autostart'];
    return DirectRecordRequest(
      source: uri.queryParameters['source'],
      quote: uri.queryParameters['quote'],
      loopId: uri.queryParameters['loopId'],
      entryId: uri.queryParameters['entryId'],
      autoStart: auto != '0' && auto != 'false',
    );
  }

  final String? source;
  final String? quote;
  final String? loopId;
  final String? entryId;
  final bool autoStart;

  String? get line {
    final text = quote?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.length <= 220) return text;
    return text.substring(0, 220);
  }
}

/// Arms the microphone on the native audio session as soon as the app is active.
///
/// The first await is the platform channel. Capture starts after that session
/// is active, with no web-shell startup in between.
class ZeroStateRecorder with WidgetsBindingObserver {
  ZeroStateRecorder({
    MethodChannel? channel,
    Future<void> Function()? startCapture,
    this.request = const DirectRecordRequest(autoStart: false),
    this.recordingActive,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _startCapture = startCapture ?? _startOnDeviceRecorder;

  static const channelName = 'com.archiveme/zero_state_recorder';
  static const primeMethod = 'primeMicrophone';

  final MethodChannel _channel;
  final Future<void> Function() _startCapture;
  final DirectRecordRequest request;
  final bool Function()? recordingActive;

  var _armed = false;
  var _capturing = false;
  var _activation = Future<void>.value();

  ZeroStateRecorderMode get mode {
    if (request.line != null) return ZeroStateRecorderMode.quoteFirst;
    if (request.source == 'home') return ZeroStateRecorderMode.oneLineMic;
    return ZeroStateRecorderMode.micOnly;
  }

  bool get autoStart => request.autoStart;

  /// Listens for [AppLifecycleState.resumed] and primes the mic immediately.
  Future<void> arm() {
    if (_armed) return _activation;
    _armed = true;
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _activation = _onActive();
    }
    return _activation;
  }

  void disarm() {
    if (!_armed) return;
    _armed = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _activation = _onActive();
  }

  Future<void> _onActive() async {
    final alreadyRecording = _capturing || (recordingActive?.call() ?? false);
    try {
      await _channel.invokeMethod<bool>(primeMethod, {
        'alreadyRecording': alreadyRecording,
      });
    } on MissingPluginException {
      // Desktop and tests without the native recorder.
    } on PlatformException {
      // The session can still be opened by the recorder itself.
    }
    if (!autoStart || _capturing) return;
    try {
      await _startCapture();
      _capturing = true;
    } on Object {
      _capturing = false;
    }
  }

  static Future<void> _startOnDeviceRecorder() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.recording.startRecording();
  }
}
