import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'pressure_check_in_record.dart';

/// Local store for structured pressure check-in records, keyed by entry id.
///
/// Backed by the same on-device prefs file as other ArchiveMe local state —
/// no backend dependency.
class PressureCheckInStore {
  PressureCheckInStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'pressureCheckIns';

  static PressureCheckInStore instance() =>
      PressureCheckInStore(AppServices.instance.prefs);

  static PressureCheckInStore forPrefs(MobilePrefsStore prefs) =>
      PressureCheckInStore(prefs);

  Future<void> save(PressureCheckInRecord record) async {
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map[record.entryId] = record.toJson();
      return map;
    });
  }

  /// All saved records, newest first.
  Future<List<PressureCheckInRecord>> loadAll() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null) return [];
    final records = raw.values
        .whereType<Map>()
        .map((m) => PressureCheckInRecord.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }
}
