/// How the archive detected a major belief shift.
enum BeliefShiftKind {
  gradualBeliefChange,
  repeatedLanguageChange,
  confidenceChange,
  themeMigration;

  static BeliefShiftKind fromName(String? raw) {
    switch (raw) {
      case 'repeatedLanguageChange':
        return BeliefShiftKind.repeatedLanguageChange;
      case 'confidenceChange':
        return BeliefShiftKind.confidenceChange;
      case 'themeMigration':
        return BeliefShiftKind.themeMigration;
      default:
        return BeliefShiftKind.gradualBeliefChange;
    }
  }

  String get label => switch (this) {
        BeliefShiftKind.gradualBeliefChange => 'Gradual belief change',
        BeliefShiftKind.repeatedLanguageChange => 'Repeated language change',
        BeliefShiftKind.confidenceChange => 'Confidence change',
        BeliefShiftKind.themeMigration => 'Theme migration',
      };
}

/// One leg in an evidence-backed belief evolution chain.
class BeliefShiftTimelineStep {
  const BeliefShiftTimelineStep({
    required this.beliefText,
    required this.entryId,
    this.recordedAt,
  });

  final String beliefText;
  final String entryId;
  final DateTime? recordedAt;

  Map<String, dynamic> toJson() => {
        'beliefText': beliefText,
        'entryId': entryId,
        if (recordedAt != null) 'recordedAt': recordedAt!.toUtc().toIso8601String(),
      };

  static BeliefShiftTimelineStep? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final text = json['beliefText']?.toString().trim() ?? '';
    final id = json['entryId']?.toString() ?? '';
    if (text.isEmpty || id.isEmpty) return null;
    return BeliefShiftTimelineStep(
      beliefText: text,
      entryId: id,
      recordedAt: DateTime.tryParse(json['recordedAt']?.toString() ?? ''),
    );
  }
}

/// Major archive belief shift with a full evidence chain.
class BeliefShiftReport {
  const BeliefShiftReport({
    required this.id,
    required this.originalBelief,
    required this.newBelief,
    required this.confidence,
    required this.evolutionTimeline,
    required this.evidenceIds,
    required this.kind,
    this.sharedTopics = const [],
  });

  final String id;
  final String originalBelief;
  final String newBelief;
  final int confidence;
  final List<BeliefShiftTimelineStep> evolutionTimeline;
  final List<String> evidenceIds;
  final BeliefShiftKind kind;
  final List<String> sharedTopics;

  bool get hasEvidenceChain => evolutionTimeline.length >= 2;

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalBelief': originalBelief,
        'newBelief': newBelief,
        'confidence': confidence,
        'evolutionTimeline': evolutionTimeline.map((s) => s.toJson()).toList(),
        'evidenceIds': evidenceIds,
        'kind': kind.name,
        'sharedTopics': sharedTopics,
      };

  static BeliefShiftReport? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final orig = json['originalBelief']?.toString().trim() ?? '';
    final newer = json['newBelief']?.toString().trim() ?? '';
    if (orig.isEmpty || newer.isEmpty) return null;
    final timeline = <BeliefShiftTimelineStep>[];
    for (final item in json['evolutionTimeline'] as List<dynamic>? ?? []) {
      if (item is Map<String, dynamic>) {
        final step = BeliefShiftTimelineStep.fromJson(item);
        if (step != null) timeline.add(step);
      } else if (item is Map) {
        final step = BeliefShiftTimelineStep.fromJson(Map<String, dynamic>.from(item));
        if (step != null) timeline.add(step);
      }
    }
    return BeliefShiftReport(
      id: json['id']?.toString() ?? '',
      originalBelief: orig,
      newBelief: newer,
      confidence: (json['confidence'] as num?)?.toInt().clamp(0, 100) ?? 0,
      evolutionTimeline: timeline,
      evidenceIds: (json['evidenceIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      kind: BeliefShiftKind.fromName(json['kind']?.toString()),
      sharedTopics: (json['sharedTopics'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class BeliefShiftDetectionResult {
  const BeliefShiftDetectionResult({required this.reports});

  final List<BeliefShiftReport> reports;

  bool get hasMajorShifts => reports.isNotEmpty;
}
