import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Tracks processed watch audio files so WCSession retries do not duplicate entries.
class WatchAudioIngestStore {
  WatchAudioIngestStore(this._prefs);

  static const prefsKey = 'watch_audio_ingested_keys_v1';
  static const maxTrackedKeys = 200;

  final MobilePrefsStore _prefs;

  Future<Set<String>> _loadKeys() async {
    final raw = await _prefs.readMap(prefsKey);
    if (raw == null || raw.isEmpty) return {};
    return raw.keys.toSet();
  }

  Future<bool> isProcessed(String ingestKey) async {
    final keys = await _loadKeys();
    return keys.contains(ingestKey);
  }

  Future<void> markProcessed(String ingestKey) async {
    final keys = await _loadKeys()..add(ingestKey);
    final trimmed = keys.length <= maxTrackedKeys
        ? keys
        : keys.skip(keys.length - maxTrackedKeys).toSet();
    final payload = {for (final key in trimmed) key: true};
    await _prefs.writeMap(prefsKey, payload);
  }

  Future<void> resetForTest() async {
    await _prefs.writeMap(prefsKey, {});
  }
}