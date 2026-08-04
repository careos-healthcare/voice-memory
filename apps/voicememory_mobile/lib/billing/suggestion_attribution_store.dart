import '../features/monetization/domain/product_value_delivery_ledger.dart';
import '../services/app_services.dart';
import '../storage/mobile_prefs_store.dart';
import 'suggestion_attribution_event.dart';

/// Local-only suggestion-to-Pro funnel log.
///
/// Mirrors [PaywallAttributionStore]: events live in the on-device prefs file,
/// no backend, no analytics SDK changes. Capped so the file stays small.
class SuggestionAttributionStore {
  SuggestionAttributionStore(this._prefs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MobilePrefsStore _prefs;
  final DateTime Function() _now;

  static const String storageKey = 'suggestionAttribution';

  /// Oldest events are dropped beyond this cap.
  static const int maxEvents = 200;

  /// Events older than this local privacy window are discarded.
  static const Duration retention = Duration(days: 30);

  static final RegExp _safeSuggestionId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  static SuggestionAttributionStore instance() =>
      SuggestionAttributionStore(AppServices.instance.prefs);

  static SuggestionAttributionStore forPrefs(
    MobilePrefsStore prefs, {
    DateTime Function()? now,
  }) => SuggestionAttributionStore(prefs, now: now);

  Future<void> record(
    SuggestionAttributionEventType type, {
    String? suggestionId,
    DateTime? now,
  }) async {
    final recordedAt = now ?? _now();
    final event = SuggestionAttributionEvent(
      type: type,
      suggestionId: sanitizeSuggestionId(suggestionId),
      at: recordedAt,
    );
    try {
      await _prefs.updateMap(storageKey, (current) {
        final events = _parseAndPrune(current?['events'], recordedAt);
        events.add(event);
        return {'events': _capped(events).map((e) => e.toJson()).toList()};
      });
    } catch (_) {
      // Attribution is best-effort and must never interrupt save/paywall flows.
    }
  }

  /// All recorded events, oldest first. Unparseable entries are skipped.
  Future<List<SuggestionAttributionEvent>> events() => _eventsAt(_now());

  Future<List<SuggestionAttributionEvent>> _eventsAt(DateTime readAt) async {
    final data = await _prefs.readJsonMap(storageKey);
    final raw = data?['events'];
    if (raw is! List) return const [];
    final pruned = _capped(_parseAndPrune(raw, readAt));
    await _prefs.writeJsonMap(storageKey, {
      'events': pruned.map((e) => e.toJson()).toList(),
    });
    return pruned;
  }

  /// Removes the entire prefs key instead of retaining an empty envelope.
  Future<void> clear() => _prefs.remove(storageKey);

  /// Strict serialization used by the allowlisted behavioral-log export.
  Future<List<Map<String, dynamic>>> exportRecords({DateTime? now}) async =>
      (await _eventsAt(now ?? _now()))
          .map(
            (event) => <String, dynamic>{
              'type': event.type.id,
              'at': event.at.toUtc().toIso8601String(),
              if (event.suggestionId != null)
                'suggestionId': event.suggestionId,
            },
          )
          .toList();

  static String? sanitizeSuggestionId(String? value) {
    if (value == null || !_safeSuggestionId.hasMatch(value)) return null;
    return value;
  }

  /// Events of one funnel stage, oldest first.
  Future<List<SuggestionAttributionEvent>> eventsOfType(
    SuggestionAttributionEventType type,
  ) async => (await events()).where((e) => e.type == type).toList();

  static List<SuggestionAttributionEvent> _parseAndPrune(
    dynamic raw,
    DateTime now,
  ) {
    if (raw is! List) return [];
    final cutoff = now.subtract(retention);
    return raw
        .whereType<Map>()
        .map(
          (item) => SuggestionAttributionEvent.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .whereType<SuggestionAttributionEvent>()
        .where((event) => !event.at.isBefore(cutoff))
        .map(
          (event) => SuggestionAttributionEvent(
            type: event.type,
            at: event.at,
            suggestionId: sanitizeSuggestionId(event.suggestionId),
          ),
        )
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  static List<SuggestionAttributionEvent> _capped(
    List<SuggestionAttributionEvent> events,
  ) => events.length <= maxEvents
      ? events
      : events.sublist(events.length - maxEvents);
}

/// Decides whether the post-save Pro nudge may show after a recording that
/// came from a daily suggestion. Conservative on purpose: never for Pro users,
/// never before ArchiveMe has delivered a valid artifact the user has seen,
/// and never twice in one session.
///
/// Saved-entry totals are not evidence of value, so they no longer open this
/// nudge.
class SuggestionProTrigger {
  static bool shouldShow({
    required bool isPro,
    required ProductValueDeliveryLedger deliveredProof,
    required bool alreadyShownThisSession,
  }) =>
      !isPro &&
      deliveredProof.deliveredArtifactIds.isNotEmpty &&
      !alreadyShownThisSession;
}
