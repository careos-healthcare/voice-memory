import '../services/app_services.dart';
import '../storage/mobile_prefs_store.dart';
import 'paywall_attribution_event.dart';
import 'paywall_source.dart';

/// Local-only paywall source attribution log.
///
/// Mirrors the other prefs-backed stores: events live in the on-device prefs
/// file, no backend, no analytics SDK changes. Capped so the file stays small.
class PaywallAttributionStore {
  PaywallAttributionStore(this._prefs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MobilePrefsStore _prefs;
  final DateTime Function() _now;

  static const String storageKey = 'paywallAttribution';

  /// Oldest events are dropped beyond this cap.
  static const int maxEvents = 200;

  /// Events older than this local privacy window are discarded.
  static const Duration retention = Duration(days: 30);

  static PaywallAttributionStore instance() =>
      PaywallAttributionStore(AppServices.instance.prefs);

  static PaywallAttributionStore forPrefs(
    MobilePrefsStore prefs, {
    DateTime Function()? now,
  }) => PaywallAttributionStore(prefs, now: now);

  Future<void> record(
    PaywallAttributionEventType type, {
    required PaywallSource source,
    String? sourceRoute,
    DateTime? now,
  }) async {
    final recordedAt = now ?? _now();
    final event = PaywallAttributionEvent(
      type: type,
      source: source,
      // The source enum already captures the useful category. Raw routes can
      // contain query strings or user identifiers, so they are not persisted.
      sourceRoute: null,
      at: recordedAt,
    );
    try {
      await _prefs.updateMap(storageKey, (current) {
        final events = _parseAndPrune(current?['events'], recordedAt);
        events.add(event);
        return {'events': _capped(events).map((e) => e.toJson()).toList()};
      });
    } catch (_) {
      // Attribution is best-effort and must never interrupt purchase flows.
    }
  }

  /// All recorded events, oldest first. Unparseable entries are skipped.
  Future<List<PaywallAttributionEvent>> events() => _eventsAt(_now());

  Future<List<PaywallAttributionEvent>> _eventsAt(DateTime readAt) async {
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
              'source': event.source.id,
              'at': event.at.toUtc().toIso8601String(),
            },
          )
          .toList();

  /// Events of one funnel stage, oldest first.
  Future<List<PaywallAttributionEvent>> eventsOfType(
    PaywallAttributionEventType type,
  ) async => (await events()).where((e) => e.type == type).toList();

  static List<PaywallAttributionEvent> _parseAndPrune(
    dynamic raw,
    DateTime now,
  ) {
    if (raw is! List) return [];
    final cutoff = now.subtract(retention);
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              PaywallAttributionEvent.fromJson(Map<String, dynamic>.from(item)),
        )
        .whereType<PaywallAttributionEvent>()
        .where((event) => !event.at.isBefore(cutoff))
        .map(
          (event) => PaywallAttributionEvent(
            type: event.type,
            source: event.source,
            at: event.at,
          ),
        )
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  static List<PaywallAttributionEvent> _capped(
    List<PaywallAttributionEvent> events,
  ) => events.length <= maxEvents
      ? events
      : events.sublist(events.length - maxEvents);
}
