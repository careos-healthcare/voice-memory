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
    final type = PaywallAttributionEventType.fromId(json['type'] as String?);
    final source = PaywallSource.fromId(json['source'] as String?);
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if (type == null || source == null || at == null) return null;
    return PaywallAttributionEvent(
      type: type,
      source: source,
      at: at,
      sourceRoute: json['sourceRoute'] as String?,
    );
  }
}
