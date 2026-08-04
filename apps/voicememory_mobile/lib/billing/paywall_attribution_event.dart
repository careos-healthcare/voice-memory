import 'paywall_source.dart';

/// Paywall funnel stages tracked for source attribution.
enum PaywallAttributionEventType {
  paywallSeen(id: 'paywall_seen'),
  purchaseStarted(id: 'purchase_started'),
  purchaseCompleted(id: 'purchase_completed'),
  restoreStarted(id: 'restore_started'),
  restoreCompleted(id: 'restore_completed');

  const PaywallAttributionEventType({required this.id});

  /// Stable id, safe to log/persist.
  final String id;

  static PaywallAttributionEventType? fromId(String? id) {
    if (id == null) return null;
    for (final type in PaywallAttributionEventType.values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// One locally recorded paywall funnel event tied to the source that opened
/// the paywall. Local-only — never sent to a backend.
class PaywallAttributionEvent {
  const PaywallAttributionEvent({
    required this.type,
    required this.source,
    required this.at,
    this.sourceRoute,
  });

  final PaywallAttributionEventType type;
  final PaywallSource source;
  final DateTime at;
  final String? sourceRoute;

  Map<String, dynamic> toJson() => {
    'type': type.id,
    'source': source.id,
    'at': at.toIso8601String(),
    if (sourceRoute != null) 'sourceRoute': sourceRoute,
  };

  static PaywallAttributionEvent? fromJson(Map<String, dynamic> json) {
    final typeRaw = json['type'];
    final sourceRaw = json['source'];
    final atRaw = json['at'];
    final type = PaywallAttributionEventType.fromId(
      typeRaw is String ? typeRaw : null,
    );
    final source = PaywallSource.fromId(sourceRaw is String ? sourceRaw : null);
    final at = DateTime.tryParse(atRaw is String ? atRaw : '');
    if (type == null || source == null || at == null) return null;
    final sourceRouteRaw = json['sourceRoute'];
    return PaywallAttributionEvent(
      type: type,
      source: source,
      at: at,
      sourceRoute: sourceRouteRaw is String ? sourceRouteRaw : null,
    );
  }
}
