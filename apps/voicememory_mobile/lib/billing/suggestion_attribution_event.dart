import 'paywall_source.dart';

/// Local-only funnel stages from Daily Return Suggestions / Start here today
/// through to a Pro purchase.
enum SuggestionAttributionEventType {
  dailySuggestionsSeen(id: 'daily_suggestions_seen'),
  startHereTapped(id: 'start_here_tapped'),
  dailySuggestionTapped(id: 'daily_suggestion_tapped'),
  startHereRecordingSaved(id: 'start_here_recording_saved'),
  dailySuggestionRecordingSaved(id: 'daily_suggestion_recording_saved'),
  suggestionToPaywallSeen(id: 'suggestion_to_paywall_seen'),
  suggestionToPurchaseStarted(id: 'suggestion_to_purchase_started'),
  suggestionToPurchaseCompleted(id: 'suggestion_to_purchase_completed');

  const SuggestionAttributionEventType({required this.id});

  /// Stable id, safe to log/persist.
  final String id;

  static SuggestionAttributionEventType? fromId(String? id) {
    if (id == null) return null;
    for (final type in SuggestionAttributionEventType.values) {
      if (type.id == id) return type;
    }
    return null;
  }

  /// Tap event for a suggestion surface.
  static SuggestionAttributionEventType tappedFor(PaywallSource source) =>
      source == PaywallSource.startHereToday
          ? startHereTapped
          : dailySuggestionTapped;

  /// Recording-saved event for a suggestion surface.
  static SuggestionAttributionEventType savedFor(PaywallSource source) =>
      source == PaywallSource.startHereToday
          ? startHereRecordingSaved
          : dailySuggestionRecordingSaved;
}

/// One locally recorded suggestion funnel event. Local-only — never sent to a
/// backend.
class SuggestionAttributionEvent {
  const SuggestionAttributionEvent({
    required this.type,
    required this.at,
    this.suggestionId,
  });

  final SuggestionAttributionEventType type;
  final DateTime at;

  /// The tapped/saved suggestion's id, when one applies.
  final String? suggestionId;

  Map<String, dynamic> toJson() => {
        'type': type.id,
        'at': at.toIso8601String(),
        if (suggestionId != null) 'suggestionId': suggestionId,
      };

  static SuggestionAttributionEvent? fromJson(Map<String, dynamic> json) {
    final type = SuggestionAttributionEventType.fromId(json['type'] as String?);
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if (type == null || at == null) return null;
    return SuggestionAttributionEvent(
      type: type,
      at: at,
      suggestionId: json['suggestionId'] as String?,
    );
  }
}
