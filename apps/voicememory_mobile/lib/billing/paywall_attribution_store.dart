import '../services/app_services.dart';
import '../storage/mobile_prefs_store.dart';
import 'paywall_attribution_event.dart';
import 'paywall_source.dart';

/// Local-only paywall source attribution log.
///
/// Mirrors the other prefs-backed stores: events live in the on-device prefs
/// file, no backend, no analytics SDK changes. Capped so the file stays small.
class PaywallAttributionStore {
  PaywallAttributionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const String storageKey = 'paywallAttribution';

  /// Oldest events are dropped beyond this cap.
  static const int maxEvents = 200;

  static PaywallAttributionStore instance() =>
      PaywallAttributionStore(AppServices.instance.prefs);

  static PaywallAttributionStore forPrefs(MobilePrefsStore prefs) =>
      PaywallAttributionStore(prefs);

  Future<void> record(
    PaywallAttributionEventType type, {
    required PaywallSource source,
    String? sourceRoute,
    DateTime? now,
  }) async {
    final event = PaywallAttributionEvent(
      type: type,
      source: source,
      sourceRoute: sourceRoute,
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
  Future<List<PaywallAttributionEvent>> events() async {
    final data = await _prefs.readJsonMap(storageKey);
    final raw = data?['events'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) =>
            PaywallAttributionEvent.fromJson(Map<String, dynamic>.from(e)))
        .whereType<PaywallAttributionEvent>()
        .toList();
  }

  /// Events of one funnel stage, oldest first.
  Future<List<PaywallAttributionEvent>> eventsOfType(
    PaywallAttributionEventType type,
  ) async =>
      (await events()).where((e) => e.type == type).toList();
}
