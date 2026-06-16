/// Detected tension between two reflection-backed statements.
class ContradictionReport {
  const ContradictionReport({
    required this.id,
    required this.originalStatement,
    required this.conflictingStatement,
    required this.confidenceScore,
    required this.originalEntryId,
    required this.conflictingEntryId,
    required this.kind,
    required this.sharedThemes,
  });

  final String id;
  final String originalStatement;
  final String conflictingStatement;
  final int confidenceScore;
  final String originalEntryId;
  final String conflictingEntryId;
  final ContradictionKind kind;
  final List<String> sharedThemes;

  List<String> get recordingIds => [originalEntryId, conflictingEntryId];

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalStatement': originalStatement,
    'conflictingStatement': conflictingStatement,
    'confidenceScore': confidenceScore,
    'originalEntryId': originalEntryId,
    'conflictingEntryId': conflictingEntryId,
    'kind': kind.name,
    'sharedThemes': sharedThemes,
    'recordingIds': recordingIds,
  };

  static ContradictionReport? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final orig = json['originalStatement']?.toString().trim() ?? '';
    final conflict = json['conflictingStatement']?.toString().trim() ?? '';
    if (orig.isEmpty || conflict.isEmpty) return null;
    return ContradictionReport(
      id: json['id']?.toString() ?? '',
      originalStatement: orig,
      conflictingStatement: conflict,
      confidenceScore:
          (json['confidenceScore'] as num?)?.toInt().clamp(0, 100) ?? 0,
      originalEntryId: json['originalEntryId']?.toString() ?? '',
      conflictingEntryId: json['conflictingEntryId']?.toString() ?? '',
      kind: ContradictionKind.fromName(json['kind']?.toString()),
      sharedThemes: (json['sharedThemes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

enum ContradictionKind {
  opposingStatements,
  reversedTheme,
  changedLanguage,
  gradualShift;

  static ContradictionKind fromName(String? raw) {
    switch (raw) {
      case 'reversedTheme':
        return ContradictionKind.reversedTheme;
      case 'changedLanguage':
        return ContradictionKind.changedLanguage;
      case 'gradualShift':
        return ContradictionKind.gradualShift;
      default:
        return ContradictionKind.opposingStatements;
    }
  }

  String get label => switch (this) {
    ContradictionKind.opposingStatements => 'Opposing statements',
    ContradictionKind.reversedTheme => 'Reversed theme',
    ContradictionKind.changedLanguage => 'Changed language',
    ContradictionKind.gradualShift => 'Gradual shift',
  };
}

class ContradictionDetectionResult {
  const ContradictionDetectionResult({
    required this.reports,
    this.currentBelief,
  });

  final List<ContradictionReport> reports;
  final String? currentBelief;

  bool get hasPossibleBeliefChange => reports.isNotEmpty;
}
