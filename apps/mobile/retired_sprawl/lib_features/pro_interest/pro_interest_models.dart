/// Pro value options users can mark interest in — mirrors Pro value bullets.
enum ProInterestValueId {
  longerArchiveHistory,
  deeperBeliefTimeline,
  moreWatchThemes,
  richerReviews,
  advancedExport,
  deeperContextViews,
}

/// Local pricing intent — interest only, not a purchase.
enum ProInterestPricingIntentId {
  freeFirst,
  lowMonthly,
  yearly,
  notEnoughValue,
}

/// Persisted Pro interest signal — local metadata only.
class ProInterestState {
  const ProInterestState({
    this.selectedValueIds = const [],
    this.pricingIntentId,
    this.note,
    this.sourceRoute,
    this.createdAt,
    this.updatedAt,
  });

  static const empty = ProInterestState();

  final List<ProInterestValueId> selectedValueIds;
  final ProInterestPricingIntentId? pricingIntentId;
  final String? note;
  final String? sourceRoute;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasCapture => selectedValueIds.isNotEmpty || pricingIntentId != null;

  bool get optionalNotePresent => note?.trim().isNotEmpty == true;

  ProInterestState copyWith({
    List<ProInterestValueId>? selectedValueIds,
    ProInterestPricingIntentId? pricingIntentId,
    bool clearPricingIntent = false,
    String? note,
    bool clearNote = false,
    String? sourceRoute,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProInterestState(
      selectedValueIds: selectedValueIds ?? this.selectedValueIds,
      pricingIntentId: clearPricingIntent
          ? null
          : (pricingIntentId ?? this.pricingIntentId),
      note: clearNote ? null : (note ?? this.note),
      sourceRoute: sourceRoute ?? this.sourceRoute,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'selectedValueIds': selectedValueIds
        .map((id) => id.name)
        .toList(growable: false),
    if (pricingIntentId != null) 'pricingIntentId': pricingIntentId!.name,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    if (sourceRoute != null && sourceRoute!.trim().isNotEmpty)
      'sourceRoute': sourceRoute!.trim(),
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  static ProInterestState fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    final ids = <ProInterestValueId>[];
    final rawIds = json['selectedValueIds'];
    if (rawIds is List) {
      for (final raw in rawIds) {
        if (raw is! String) continue;
        for (final value in ProInterestValueId.values) {
          if (value.name == raw) {
            ids.add(value);
            break;
          }
        }
      }
    }
    ProInterestPricingIntentId? pricing;
    final pricingRaw = json['pricingIntentId'];
    if (pricingRaw is String) {
      for (final value in ProInterestPricingIntentId.values) {
        if (value.name == pricingRaw) {
          pricing = value;
          break;
        }
      }
    }
    DateTime? createdAt;
    DateTime? updatedAt;
    final createdRaw = json['createdAt'];
    if (createdRaw is String) createdAt = DateTime.tryParse(createdRaw);
    final updatedRaw = json['updatedAt'];
    if (updatedRaw is String) updatedAt = DateTime.tryParse(updatedRaw);
    final note = json['note'];
    final sourceRoute = json['sourceRoute'];
    return ProInterestState(
      selectedValueIds: ids,
      pricingIntentId: pricing,
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
      sourceRoute: sourceRoute is String && sourceRoute.trim().isNotEmpty
          ? sourceRoute.trim()
          : null,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}