import 'pressure_check_in_option.dart';
import 'pressure_context.dart';

/// Local-only metadata saved alongside a pressure check-in journal entry.
///
/// The journal entry holds the evidence-grade transcript; this record keeps the
/// structured signal (which option, optional context, optional fear, whether
/// the user chose to stop) used by the loop-visibility, recap, and reflection
/// engines without any backend dependency.
class PressureCheckInRecord {
  const PressureCheckInRecord({
    required this.entryId,
    required this.createdAt,
    required this.optionId,
    this.contextIds = const [],
    this.fear,
    this.stopCostNote,
    this.choseToStop = false,
    this.transcript = '',
  });

  final String entryId;
  final DateTime createdAt;
  final String optionId;
  final List<String> contextIds;
  final String? fear;
  final String? stopCostNote;
  final bool choseToStop;
  final String transcript;

  PressureCheckInOption? get option => PressureCheckInOption.fromId(optionId);

  List<PressureContext> get contexts => contextIds
      .map(PressureContext.fromId)
      .whereType<PressureContext>()
      .toList();

  Map<String, dynamic> toJson() => {
        'entryId': entryId,
        'createdAt': createdAt.toIso8601String(),
        'optionId': optionId,
        'contextIds': contextIds,
        if (fear != null) 'fear': fear,
        if (stopCostNote != null) 'stopCostNote': stopCostNote,
        'choseToStop': choseToStop,
        'transcript': transcript,
      };

  factory PressureCheckInRecord.fromJson(Map<String, dynamic> json) {
    final contexts = (json['contextIds'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    return PressureCheckInRecord(
      entryId: json['entryId'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      optionId: json['optionId'] as String? ?? '',
      contextIds: contexts,
      fear: _optional(json['fear']),
      stopCostNote: _optional(json['stopCostNote']),
      choseToStop: json['choseToStop'] == true,
      transcript: json['transcript'] as String? ?? '',
    );
  }

  static String? _optional(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
