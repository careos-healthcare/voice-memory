import 'package:archiveme_mobile/features/wearable/wearable_ingestion_worker.dart';
import 'package:flutter/services.dart';

/// Listens for WatchOS and WearOS recordings over method channels.
class WearableSyncService {
  WearableSyncService({
    required this.worker,
    MethodChannel? watchOs,
    MethodChannel? wearOs,
    this.backgroundSync = true,
  }) : watchOs = watchOs ?? const MethodChannel(watchOsChannelName),
       wearOs = wearOs ?? const MethodChannel(wearOsChannelName);

  static const watchOsChannelName = 'com.archiveme/wearable_watchos';
  static const wearOsChannelName = 'com.archiveme/wearable_wearos';
  static const readyMethod = 'wearableRecordingReady';
  static const consumePendingMethod = 'consumePendingWearableAudio';
  static const statusMethod = 'wearableConnectionStatus';
  static const statusChangedMethod = 'wearableStatusChanged';

  final WearableIngestionWorker worker;
  final MethodChannel watchOs;
  final MethodChannel wearOs;
  bool backgroundSync;
  bool connected = false;
  final List<WearableAudioClip> pending = [];

  var _bound = false;

  Future<void> bind() async {
    if (_bound) return;
    _bound = true;
    _listen(watchOs, 'watchos');
    _listen(wearOs, 'wearos');
    await _pull(watchOs, 'watchos');
    await _pull(wearOs, 'wearos');
    await _drainIfReady();
  }

  Future<void> setBackgroundSync({required bool enabled}) async {
    backgroundSync = enabled;
    await _drainIfReady();
  }

  Future<void> setConnected({required bool value}) async {
    connected = value;
    await _drainIfReady();
  }

  void dispose() {
    watchOs.setMethodCallHandler(null);
    wearOs.setMethodCallHandler(null);
    _bound = false;
  }

  void _listen(MethodChannel channel, String platform) {
    channel.setMethodCallHandler((call) async {
      if (call.method == readyMethod) {
        await _accept(call.arguments, platform);
        return;
      }
      if (call.method == statusChangedMethod) {
        await setConnected(value: _connectedFlag(call.arguments));
      }
    });
  }

  Future<void> _pull(MethodChannel channel, String platform) async {
    try {
      final status = await channel.invokeMethod<Object?>(statusMethod);
      if (_connectedFlag(status)) connected = true;
      final waiting = await channel.invokeMethod<List<dynamic>>(
        consumePendingMethod,
      );
      for (final raw in waiting ?? const <dynamic>[]) {
        await _accept(raw, platform, drain: false);
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> _accept(
    Object? raw,
    String platform, {
    bool drain = true,
  }) async {
    final clip = WearableAudioClip.fromPlatform(raw, platform: platform);
    if (clip == null || !clip.isSupportedAudio) return;
    pending.add(clip);
    if (drain) await _drainIfReady();
  }

  Future<void> _drainIfReady() async {
    if (!connected || !backgroundSync || pending.isEmpty) return;
    final batch = List<WearableAudioClip>.of(pending);
    pending.clear();
    for (final clip in batch) {
      final indexed = await worker.ingest(clip);
      if (!indexed) pending.add(clip);
    }
  }

  static bool _connectedFlag(Object? raw) {
    if (raw is bool) return raw;
    if (raw is Map) return raw['connected'] == true;
    return false;
  }
}
