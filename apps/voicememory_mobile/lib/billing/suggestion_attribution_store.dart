import '../services/app_services.dart';
import '../storage/mobile_prefs_store.dart';
import 'suggestion_attribution_event.dart';

/// Local-only suggestion-to-Pro funnel log.
///
/// Mirrors [PaywallAttributionStore]: events live in the on-device prefs file,
/// no backend, no analytics SDK changes. Capped so the file stays small.
class SuggestionAttributionStore {
  SuggestionAttributionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const String storageKey = 'suggestionAttribution';

  /// Oldest events are dropped beyond this cap.
  static const int maxEvents = 200;

  static SuggestionAttributionStore instance() =>
      SuggestionAttributionStore(AppServices.instance.prefs);

  static SuggestionAttributionStore forPrefs(MobilePrefsStore prefs) =>
      SuggestionAttributionStore(prefs);

  Future<void> record(
    SuggestionAttributionEventType type, {
    String? suggestionId,
    DateTime? now,
  }) async {
    final event = SuggestionAttributionEvent(
      type: type,
      suggestionId: suggestionId,
      at: now ?? DateTime.now(),
    );
    await _prefs.updateMap(storageKey, (current) {
      final raw = current?['events'];
      final events = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
      events.add(event.toJson());
      if (events.length > maxEvents) {
        events.removeRange(0, events.length - maxEvents);
      }
      return {'events': events};
    });
  }

  /// All recorded events, oldest first. Unparseable entries are skipped.
  Future<List<SuggestionAttributionEvent>> events() async {
    final data = await _prefs.readJsonMap(storageKey);
    final raw = data?['events'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) =>
              SuggestionAttributionEvent.fromJson(Map<String, dynamic>.from(e)),
        )
        .whereType<SuggestionAttributionEvent>()
        .toList();
  }

  /// Events of one funnel stage, oldest first.
  Future<List<SuggestionAttributionEvent>> eventsOfType(
    SuggestionAttributionEventType type,
  ) async => (await events()).where((e) => e.type == type).toList();
}

/// Decides whether the post-save Pro nudge may show after a recording that
/// came from a daily suggestion. Conservative on purpose: never for Pro users,
/// never before three saved entries, never twice in one session.
class SuggestionProTrigger {
  static bool shouldShow({
    required bool isPro,
    required int entryCount,
    required bool alreadyShownThisSession,
  }) => !isPro && entryCount >= 3 && !alreadyShownThisSession;
}
