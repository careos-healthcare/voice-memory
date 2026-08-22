import 'package:archiveme_mobile/features/offline_sync/archive_integrity_snapshot.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists offline sync verification journey across app restart.
class OfflineSyncJourneyStore {
  OfflineSyncJourneyStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'offline_sync_journey_v1';

  Future<Map<String, dynamic>> _read() async =>
      (await _prefs.readMap(_key)) ?? {};

  Future<void> _write(Map<String, dynamic> data) async {
    await _prefs.writeMap(_key, data);
  }

  Future<void> reset() async => _write({});

  Future<void> markAirplaneModeStarted() async {
    final snap = await ArchiveIntegritySnapshot.capture();
    final raw = await _read();
    raw['airplaneStartedAt'] = DateTime.now().toUtc().toIso8601String();
    raw['eligibleAtAirplane'] = snap.eligibleCount;
    raw['startSnapshot'] = snap.toJson();
    raw['restartVerified'] = false;
    raw['baselineLocked'] = false;
    await _write(raw);
  }

  Future<int> eligibleAtAirplane() async {
    final raw = await _read();
    return (raw['eligibleAtAirplane'] as num?)?.toInt() ?? 0;
  }

  Future<void> lockOfflineBaseline({
    required int reflectionsRecordedOffline,
    required ArchiveIntegritySnapshot lockSnapshot,
    required List<String> offlineTimestamps,
  }) async {
    final raw = await _read();
    raw['baselineLocked'] = true;
    raw['reflectionsRecordedOffline'] = reflectionsRecordedOffline;
    raw['baselineSnapshot'] = lockSnapshot.toJson();
    raw['offlineTimestamps'] = offlineTimestamps;
    raw['restartVerified'] = false;
    await _write(raw);
  }

  Future<List<String>> offlineTimestamps() async {
    final raw = await _read();
    final list = raw['offlineTimestamps'];
    if (list is! List) return [];
    return list.map((e) => e.toString()).toList();
  }

  Future<bool> isBaselineLocked() async {
    final raw = await _read();
    return raw['baselineLocked'] == true;
  }

  Future<int> reflectionsRecordedOffline() async {
    final raw = await _read();
    return (raw['reflectionsRecordedOffline'] as num?)?.toInt() ?? 0;
  }

  Future<ArchiveIntegritySnapshot?> startSnapshot() async {
    final raw = await _read();
    final block = raw['startSnapshot'];
    if (block is! Map) return null;
    return ArchiveIntegritySnapshot.fromJson(Map<String, dynamic>.from(block));
  }

  Future<ArchiveIntegritySnapshot?> baselineSnapshot() async {
    final raw = await _read();
    final block = raw['baselineSnapshot'];
    if (block is! Map) return null;
    return ArchiveIntegritySnapshot.fromJson(Map<String, dynamic>.from(block));
  }

  Future<void> markRestartVerified() async {
    final raw = await _read();
    raw['restartVerified'] = true;
    await _write(raw);
  }

  Future<bool> isRestartVerified() async {
    final raw = await _read();
    return raw['restartVerified'] == true;
  }

  Future<void> markNetworkRestored() async {
    final raw = await _read();
    raw['networkRestoredAt'] = DateTime.now().toUtc().toIso8601String();
    await _write(raw);
  }
}