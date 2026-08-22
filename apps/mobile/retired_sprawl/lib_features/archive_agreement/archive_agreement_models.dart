/// User response to the archive's current theory (metadata only).
enum ArchiveTheoryAgreementResponse { agree, unsure, disagree }

/// One saved agreement event.
class ArchiveAgreementRecord {
  const ArchiveAgreementRecord({
    required this.id,
    required this.theoryStatement,
    required this.theoryKey,
    required this.response,
    required this.recordedAt,
    this.confidencePercent,
  });

  final String id;
  final String theoryStatement;
  final String theoryKey;
  final ArchiveTheoryAgreementResponse response;
  final DateTime recordedAt;
  final int? confidencePercent;

  Map<String, dynamic> toJson() => {
    'id': id,
    'theoryStatement': theoryStatement,
    'theoryKey': theoryKey,
    'response': response.name,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    if (confidencePercent != null) 'confidencePercent': confidencePercent,
  };

  static ArchiveAgreementRecord? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString() ?? '';
    final statement = json['theoryStatement']?.toString() ?? '';
    final key = json['theoryKey']?.toString() ?? '';
    final response = ArchiveTheoryAgreementResponse.values
        .asNameMap()[json['response']?.toString()];
    final at = DateTime.tryParse(json['recordedAt']?.toString() ?? '');
    if (id.isEmpty || statement.isEmpty || response == null || at == null) {
      return null;
    }
    return ArchiveAgreementRecord(
      id: id,
      theoryStatement: statement,
      theoryKey: key.isNotEmpty ? key : _normalizeKey(statement),
      response: response,
      recordedAt: at,
      confidencePercent: (json['confidencePercent'] as num?)?.toInt(),
    );
  }

  static String _normalizeKey(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// History slice for UI.
class ArchiveAgreementHistoryView {
  const ArchiveAgreementHistoryView({
    required this.records,
    required this.latestForCurrentTheory,
  });

  final List<ArchiveAgreementRecord> records;
  final ArchiveAgreementRecord? latestForCurrentTheory;

  bool get hasHistory => records.isNotEmpty;
}