import '../../storage/mobile_prefs_store.dart';

/// Calendar days when the archive surfaced a meaningful discovery.
class DiscoveryStreakStore {
  DiscoveryStreakStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _daysKey = 'livingArchiveDiscoveryDays';

  Future<Set<String>> readDiscoveryDays() async {
    final raw = await _prefs.readJsonMap(_daysKey);
    final list = raw?['days'];
    if (list is! List) return {};
    return list.map((e) => e.toString()).toSet();
  }

  Future<void> recordDiscoveryDay(DateTime day) async {
    final days = await readDiscoveryDays();
    days.add(dayKey(day));
    final sorted = days.toList()..sort();
    final trimmed = sorted.length > 120
        ? sorted.sublist(sorted.length - 120)
        : sorted;
    await _prefs.writeJsonMap(_daysKey, {'days': trimmed});
  }

  static String dayKey(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
