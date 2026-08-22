import 'package:archiveme_mobile/features/review_ritual/view_ritual_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local-only review ritual persistence — no journal text, no uploads.
class ReviewRitualStore {
  ReviewRitualStore(this._prefs);

  static const prefsKey = 'archiveReviewRitual';

  final MobilePrefsStore _prefs;

  static ReviewRitual? _cached;
  static bool _loaded = false;

  static ReviewRitual? get cached => _cached;

  static ReviewRitualStore instance() =>
      ReviewRitualStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().load();
    _loaded = true;
  }

  Future<ReviewRitual?> load() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return null;
    final ritual = ReviewRitual.fromJson(raw);
    return ritual.isConfigured ? ritual : null;
  }

  Future<void> save(ReviewRitual ritual) async {
    final now = DateTime.now().toUtc();
    final existing = _cached;
    final next = ReviewRitual(
      selectedDay: ritual.selectedDay,
      selectedDaypart: ritual.selectedDaypart,
      focusRepeated: ritual.focusRepeated,
      focusChanged: ritual.focusChanged,
      focusWatchNext: ritual.focusWatchNext,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _prefs.writeJsonMap(prefsKey, next.toJson());
    _cached = next;
    _loaded = true;
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _prefs.writeJsonMap(prefsKey, {});
  }

  static Future<void> clearAll() async {
    _cached = null;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _cached = null;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
  }

  @visibleForTesting
  static void seedForTest(ReviewRitual? ritual) {
    _cached = ritual;
    _loaded = true;
  }
}