import 'package:archiveme_mobile/core/user/progressive_disclosure.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks journal volume and distinct active days for progressive disclosure.
class UserMilestoneService {
  UserMilestoneService({
    required MobilePrefsStore this._prefs,
    required Future<List<JournalEntry>> Function() this._loadEntries,
  });

  static const prefsKey = 'user_milestones_v1';

  final MobilePrefsStore _prefs;
  final Future<List<JournalEntry>> Function() _loadEntries;

  /// Production constructor — journal + prefs from [AppServices].
  static UserMilestoneService fromAppServices() {
    return UserMilestoneService(
      prefs: AppServices.instance.prefs,
      loadEntries: () => AppServices.instance.journal.loadAll(),
    );
  }

  /// Records today as an active day, then returns the current snapshot.
  Future<UserMilestoneSnapshot> recordAppOpen({DateTime? now}) async {
    final today = dayKey(now ?? DateTime.now().toUtc());
    await _prefs.updateMap(prefsKey, (current) {
      final days = _readDayKeys(current);
      days.add(today);
      return {
        'activeDays': days.toList()..sort(),
        'firstOpenAt':
            current?['firstOpenAt'] ?? DateTime.now().toUtc().toIso8601String(),
      };
    });
    return load();
  }

  Future<UserMilestoneSnapshot> load() async {
    final stored = await _prefs.readJsonMap(prefsKey);
    final recordedDays = _readDayKeys(stored);
    final entries = await _safeLoadEntries();
    final entryDays = {
      for (final entry in entries) dayKey(entry.createdAt.toUtc()),
    };
    final activeDays = {...recordedDays, ...entryDays};
    return UserMilestoneSnapshot(
      journalEntryCount: entries.length,
      daysActive: activeDays.length,
      activeDayKeys: activeDays,
    );
  }

  @visibleForTesting
  static String dayKey(DateTime value) {
    final utc = value.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  Future<List<JournalEntry>> _safeLoadEntries() async {
    try {
      return await _loadEntries();
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'UserMilestoneService failed to load saved moments',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  static Set<String> _readDayKeys(Map<String, dynamic>? raw) {
    final days = raw?['activeDays'];
    if (days is! List) return <String>{};
    return {
      for (final day in days)
        if (day is String && day.isNotEmpty) day,
    };
  }
}

/// Live milestone snapshot for settings / onboarding widgets.
final userMilestoneSnapshotProvider = FutureProvider<UserMilestoneSnapshot>((
  ref,
) async {
  if (!AppServices.isInitialized) return UserMilestoneSnapshot.empty;
  return UserMilestoneService.fromAppServices().recordAppOpen();
});
