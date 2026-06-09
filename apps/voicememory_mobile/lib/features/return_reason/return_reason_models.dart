/// Persisted curiosity loop state after leaving Discover.
class ReturnReasonState {
  const ReturnReasonState({
    required this.pendingQuestions,
    required this.unresolvedPatterns,
    required this.emergingBeliefs,
    required this.generatedAt,
    this.primaryMessage,
    this.kind,
    this.beliefFocus,
    this.recordingsNeeded,
  });

  final List<String> pendingQuestions;
  final List<String> unresolvedPatterns;
  final List<String> emergingBeliefs;
  final DateTime generatedAt;
  final String? primaryMessage;
  final String? kind;
  final String? beliefFocus;
  final int? recordingsNeeded;

  bool get hasContent =>
      primaryMessage != null && primaryMessage!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'pendingQuestions': pendingQuestions,
        'unresolvedPatterns': unresolvedPatterns,
        'emergingBeliefs': emergingBeliefs,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'primaryMessage': primaryMessage,
        'kind': kind,
        'beliefFocus': beliefFocus,
        'recordingsNeeded': recordingsNeeded,
      };

  static ReturnReasonState? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final message = json['primaryMessage']?.toString().trim();
    if (message == null || message.isEmpty) return null;
    return ReturnReasonState(
      pendingQuestions: (json['pendingQuestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      unresolvedPatterns: (json['unresolvedPatterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      emergingBeliefs: (json['emergingBeliefs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
      primaryMessage: message,
      kind: json['kind']?.toString(),
      beliefFocus: json['beliefFocus']?.toString(),
      recordingsNeeded: (json['recordingsNeeded'] as num?)?.toInt(),
    );
  }
}

enum ReturnReasonKind {
  uncertainPatterns,
  conflictingEvidence,
  emergingBelief,
  keepRecording,
}

/// Rendered card on Archive home.
class ReturnReasonCard {
  const ReturnReasonCard({
    required this.kind,
    required this.leadLine,
    required this.bodyLines,
    required this.state,
    this.beliefQuote,
    this.recordingsNeeded,
  });

  final ReturnReasonKind kind;
  final String leadLine;
  final List<String> bodyLines;
  final ReturnReasonState state;
  final String? beliefQuote;
  final int? recordingsNeeded;
}
