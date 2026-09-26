import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/voice_capture/transcription/live_draft_availability.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/sherpa_streaming_draft.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/streaming_speech_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Partial on-device recognition while a recording is in progress.
///
/// Partials are for the recording screen only. Callers must not store them
/// as the person's words. Audio stays on the device. Android and an iOS
/// language without on-device recognition use the streaming Zipformer model,
/// fed from the recorder's PCM. The platform recogniser is the fallback.
abstract final class LiveDraftTranscript {
  static const channelName = 'archive_me/native_speech_transcription';
  static const eventChannelName =
      'archive_me/native_speech_transcription_draft';

  static const MethodChannel _channel = MethodChannel(channelName);
  static const EventChannel _events = EventChannel(eventChannelName);
  static final StreamController<String> _local = StreamController<String>.broadcast();

  /// Set in tests. When set, [supportsOnDeviceStreaming] uses this probe.
  static LiveDraftAvailability? debugAvailability;

  static StreamingSpeechModelStore? modelStore;
  static SherpaStreamingDraft? sherpa;

  static var paused = false;
  static var statusMessage = '';
  static var _feedingSherpa = false;
  static var _usingDartSherpa = false;
  static var _probed = false;
  static var _devicePathsReady = false;

  static bool get supportsOnDeviceStreaming {
    final probe = debugAvailability;
    if (probe != null) return probe.supportsStreaming;
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    if (!_probed) return true;
    return _devicePathsReady || statusMessage.isNotEmpty;
  }

  static Stream<String> partials() {
    if (!supportsOnDeviceStreaming) return const Stream.empty();
    return Stream<String>.multi((controller) {
      final native = _events.receiveBroadcastStream().listen(
        (event) {
          final text = _textOf(event);
          if (text.isNotEmpty && !paused) controller.add(text);
        },
        onError: controller.addError,
      );
      final local = _local.stream.listen((text) {
        if (!paused && text.isNotEmpty) controller.add(text);
      });
      controller.onCancel = () async {
        await native.cancel();
        await local.cancel();
      };
    });
  }

  static String _textOf(Object? event) {
    if (event is String) return event;
    if (event is Map && event['transcript'] is String) {
      return event['transcript'] as String;
    }
    return '';
  }

  /// Same PCM the recorder is already capturing. Does not open a microphone.
  static void offerCapturedPcm(Uint8List pcm) {
    if (paused || pcm.isEmpty || !_feedingSherpa) return;
    if (_usingDartSherpa) {
      final text = sherpa?.acceptPcm16(pcm);
      if (text != null && text.isNotEmpty) _local.add(text);
      return;
    }
    unawaited(
      _channel.invokeMethod<void>('feedLiveDraftPcm', pcm).catchError((_) {}),
    );
  }

  static Future<void> setPaused(bool value) async {
    paused = value;
    if (kIsWeb || debugAvailability != null) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>(
        value ? 'pauseLiveDraft' : 'resumeLiveDraft',
      );
    } on PlatformException {
      return;
    }
  }

  static Future<void> start({ConfirmedSpeechLocale? locale}) async {
    if (debugAvailability != null) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    statusMessage = '';
    final support = await getApplicationSupportDirectory();
    final modelDir = Directory(
      p.join(support.path, 'streaming_zipformer_en'),
    );
    modelStore ??= StreamingSpeechModelStore(
      supportDirectory: () async => support,
      onWifi: () async {
        final results = await Connectivity().checkConnectivity();
        return results.contains(ConnectivityResult.wifi) ||
            results.contains(ConnectivityResult.ethernet);
      },
      fetch: (onProgress) async {
        final response = await Dio().get<List<int>>(
          StreamingSpeechModel.modelUrl,
          options: Options(responseType: ResponseType.bytes),
          onReceiveProgress: onProgress,
        );
        return Uint8List.fromList(response.data ?? const <int>[]);
      },
    );
    var sherpaReady = StreamingSpeechModel(directory: modelDir).isReady;
    final probed = await _probe(locale);
    sherpaReady = sherpaReady || probed.sherpaReady;
    if (!sherpaReady) {
      statusMessage = StreamingSpeechModel.downloadingLabel;
      final dir = await modelStore!.ensure(
        onStatus: (message) => statusMessage = message,
      );
      sherpaReady = dir != null;
      if (!sherpaReady && statusMessage == StreamingSpeechModel.downloadingLabel) {
        statusMessage = '';
      }
    }
    _devicePathsReady =
        sherpaReady ||
        probed.platformRecognizerReady ||
        (Platform.isIOS && probed.iosOnDeviceReady);
    _probed = true;
    if (!_devicePathsReady && statusMessage.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('startLiveDraft', {
        if (locale != null) 'localeIdentifier': locale.identifier,
        'preferSherpa': sherpaReady,
        if (sherpaReady) 'modelDir': modelDir.path,
      });
      // Android feeds the recorder's PCM into the native stream. iOS
      // on-device recognition uses its own tap, so this session does not
      // forward PCM to a method that only Android implements.
      _feedingSherpa = sherpaReady && Platform.isAndroid;
      _usingDartSherpa = false;
    } on PlatformException catch (error) {
      if (error.code != 'on_device_unavailable' || !sherpaReady) {
        _feedingSherpa = false;
        return;
      }
      sherpa ??= SherpaStreamingDraft();
      final started = sherpa!.start(
        model: StreamingSpeechModel(directory: modelDir),
      );
      _usingDartSherpa = started;
      _feedingSherpa = started;
      _devicePathsReady = started || probed.platformRecognizerReady;
    }
  }

  static Future<LiveDraftAvailability> _probe(
    ConfirmedSpeechLocale? locale,
  ) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'probeLiveDraft',
        {if (locale != null) 'localeIdentifier': locale.identifier},
      );
      return LiveDraftAvailability(
        treatAsAndroid: Platform.isAndroid,
        treatAsIos: Platform.isIOS,
        sherpaReady: raw?['sherpa'] == true,
        platformRecognizerReady: raw?['platform'] == true,
        iosOnDeviceReady: raw?['iosOnDevice'] == true,
      );
    } on PlatformException {
      return LiveDraftAvailability(
        treatAsAndroid: Platform.isAndroid,
        treatAsIos: Platform.isIOS,
        platformRecognizerReady: Platform.isAndroid,
      );
    }
  }

  static Future<void> stop() async {
    _feedingSherpa = false;
    _usingDartSherpa = false;
    paused = false;
    statusMessage = '';
    _probed = false;
    sherpa?.stop();
    if (debugAvailability != null || kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('stopLiveDraft');
    } on PlatformException {
      return;
    }
  }
}
