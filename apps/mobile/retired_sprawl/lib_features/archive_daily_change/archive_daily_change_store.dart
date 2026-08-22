import 'package:archiveme_mobile/features/archive_daily_change/archive_daily_change_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local last-seen timestamps for daily change detection — no private text.
class ArchiveDailyChangeStore {
  ArchiveDailyChangeStore(this._prefs);

  static const prefsKey = 'archiveDailyChangeState';

  final MobilePrefsStore _prefs;

  static ArchiveDailyChangeState _cached = ArchiveDailyChangeState.empty;
  static bool _loaded = false;

  static ArchiveDailyChangeState get cached => _cached;

  static ArchiveDailyChangeStore instance() =>
      ArchiveDailyChangeStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().load();
    _loaded = true;
  }

  Future<ArchiveDailyChangeState> load() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return ArchiveDailyChangeState.empty;
    return ArchiveDailyChangeState.fromJson(raw);
  }

  Future<void> save(ArchiveDailyChangeState state) async {
    _cached = state;
    _loaded = true;
    await _prefs.writeJsonMap(prefsKey, state.toJson());
  }

  Future<void> markSeen(DateTime seenAt) async {
    await save(_cached.copyWith(lastSeenAt: seenAt, clearDismissedAt: true));
  }

  Future<void> dismiss(DateTime dismissedAt) async {
    await save(
      _cached.copyWith(dismissedAt: dismissedAt, lastSeenAt: dismissedAt),
    );
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _cached = ArchiveDailyChangeState.empty;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
  }

  @visibleForTesting
  static void seedForTest(ArchiveDailyChangeState state) {
    _cached = state;
    _loaded = true;
  }
}