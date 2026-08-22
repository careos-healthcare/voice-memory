/// GPT-5 synthesis V2 — narrative layer on deterministic archive engines.
library;

enum ArchiveSynthesisType { monthly, milestone, deepDive, historian }

extension ArchiveSynthesisTypeApi on ArchiveSynthesisType {
  String get apiValue => switch (this) {
    ArchiveSynthesisType.monthly => 'monthly',
    ArchiveSynthesisType.milestone => 'milestone',
    ArchiveSynthesisType.deepDive => 'deep_dive',
    ArchiveSynthesisType.historian => 'historian',
  };
}

class ArchiveSynthesisEvidenceRef {
  const ArchiveSynthesisEvidenceRef({
    required this.entryId,
    this.excerpt,
    this.role,
  });

  final String entryId;
  final String? excerpt;
  final String? role;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    if (excerpt != null) 'excerpt': excerpt,
    if (role != null) 'role': role,
  };

  static ArchiveSynthesisEvidenceRef? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['entryId']?.toString() ?? '';
    if (id.isEmpty) return null;
    return ArchiveSynthesisEvidenceRef(
      entryId: id,
      excerpt: json['excerpt']?.toString(),
      role: json['role']?.toString(),
    );
  }
}

class ArchiveSynthesisConclusion {
  const ArchiveSynthesisConclusion({
    required this.id,
    required this.statement,
    required this.confidencePercent,
    required this.uncertaintyNote,
    required this.evidence,
  });

  final String id;
  final String statement;
  final int confidencePercent;
  final String uncertaintyNote;
  final List<ArchiveSynthesisEvidenceRef> evidence;

  static ArchiveSynthesisConclusion? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString() ?? '';
    final statement = json['statement']?.toString() ?? '';
    final note = json['uncertaintyNote']?.toString() ?? '';
    if (id.isEmpty || statement.isEmpty || note.isEmpty) return null;
    final evidence = <ArchiveSynthesisEvidenceRef>[];
    final raw = json['evidence'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final ref = ArchiveSynthesisEvidenceRef.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (ref != null) evidence.add(ref);
      }
    }
    if (evidence.isEmpty) return null;
    return ArchiveSynthesisConclusion(
      id: id,
      statement: statement,
      confidencePercent: (json['confidencePercent'] as num?)?.toInt() ?? 0,
      uncertaintyNote: note,
      evidence: evidence,
    );
  }
}

/// Stored Archive Monthly Review (V2).
class ArchiveMonthlyReview {
  const ArchiveMonthlyReview({
    required this.monthKey,
    required this.archiveHash,
    required this.eligibleCount,
    required this.generatedAt,
    required this.model,
    required this.whatChanged,
    required this.emergingTheories,
    required this.fadingTheories,
    required this.surprises,
    required this.biggestSurprise,
    required this.strongestContradiction,
    required this.evidenceFor,
    required this.evidenceAgainst,
  });

  final String monthKey;
  final String archiveHash;
  final int eligibleCount;
  final DateTime generatedAt;
  final String model;
  final List<ArchiveSynthesisConclusion> whatChanged;
  final List<ArchiveSynthesisConclusion> emergingTheories;
  final List<ArchiveSynthesisConclusion> fadingTheories;
  final List<ArchiveSynthesisConclusion> surprises;
  final ArchiveSynthesisConclusion? biggestSurprise;
  final ArchiveSynthesisConclusion? strongestContradiction;
  final List<ArchiveSynthesisConclusion> evidenceFor;
  final List<ArchiveSynthesisConclusion> evidenceAgainst;

  bool get hasContent =>
      whatChanged.isNotEmpty ||
      emergingTheories.isNotEmpty ||
      fadingTheories.isNotEmpty ||
      surprises.isNotEmpty ||
      biggestSurprise != null ||
      strongestContradiction != null ||
      evidenceFor.isNotEmpty ||
      evidenceAgainst.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'reviewVersion': 2,
    'monthKey': monthKey,
    'archiveHash': archiveHash,
    'eligibleCount': eligibleCount,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'model': model,
    'whatChanged': whatChanged.map(conclusionToJson).toList(),
    'emergingTheories': emergingTheories.map(conclusionToJson).toList(),
    'fadingTheories': fadingTheories.map(conclusionToJson).toList(),
    'surprises': surprises.map(conclusionToJson).toList(),
    if (biggestSurprise != null)
      'biggestSurprise': conclusionToJson(biggestSurprise!),
    if (strongestContradiction != null)
      'strongestContradiction': conclusionToJson(strongestContradiction!),
    'evidenceFor': evidenceFor.map(conclusionToJson).toList(),
    'evidenceAgainst': evidenceAgainst.map(conclusionToJson).toList(),
  };

  static Map<String, dynamic> conclusionToJson(ArchiveSynthesisConclusion c) =>
      {
        'id': c.id,
        'statement': c.statement,
        'confidencePercent': c.confidencePercent,
        'uncertaintyNote': c.uncertaintyNote,
        'evidence': c.evidence.map((e) => e.toJson()).toList(),
      };

  static ArchiveMonthlyReview? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final monthKey = json['monthKey']?.toString() ?? '';
    final hash = json['archiveHash']?.toString() ?? '';
    final at = DateTime.tryParse(json['generatedAt']?.toString() ?? '');
    if (monthKey.isEmpty || hash.isEmpty || at == null) return null;

    List<ArchiveSynthesisConclusion> section(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => ArchiveSynthesisConclusion.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .whereType<ArchiveSynthesisConclusion>()
          .toList();
    }

    ArchiveSynthesisConclusion? single(String key) {
      final raw = json[key];
      if (raw is! Map) return null;
      return ArchiveSynthesisConclusion.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }

    return ArchiveMonthlyReview(
      monthKey: monthKey,
      archiveHash: hash,
      eligibleCount: (json['eligibleCount'] as num?)?.toInt() ?? 0,
      generatedAt: at,
      model: json['model']?.toString() ?? '',
      whatChanged: section('whatChanged'),
      emergingTheories: section('emergingTheories'),
      fadingTheories: section('fadingTheories'),
      surprises: section('surprises'),
      biggestSurprise: single('biggestSurprise'),
      strongestContradiction: single('strongestContradiction'),
      evidenceFor: section('evidenceFor'),
      evidenceAgainst: section('evidenceAgainst'),
    );
  }
}

/// Permanent milestone review at 50 / 100 / 200 / 500 reflections.
class ArchiveMilestoneReview {
  const ArchiveMilestoneReview({
    required this.milestoneThreshold,
    required this.eligibleCount,
    required this.archiveHash,
    required this.generatedAt,
    required this.model,
    required this.headline,
    required this.narrative,
    required this.primaryTheorySummary,
    required this.changeHighlights,
    required this.uncertaintyNote,
  });

  final int milestoneThreshold;
  final int eligibleCount;
  final String archiveHash;
  final DateTime generatedAt;
  final String model;
  final String headline;
  final String narrative;
  final ArchiveSynthesisConclusion? primaryTheorySummary;
  final List<ArchiveSynthesisConclusion> changeHighlights;
  final String uncertaintyNote;

  Map<String, dynamic> toJson() => {
    'reviewVersion': 2,
    'milestoneThreshold': milestoneThreshold,
    'eligibleCount': eligibleCount,
    'archiveHash': archiveHash,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'model': model,
    'headline': headline,
    'narrative': narrative,
    if (primaryTheorySummary != null)
      'primaryTheorySummary': ArchiveMonthlyReview.conclusionToJson(
        primaryTheorySummary!,
      ),
    'changeHighlights': changeHighlights
        .map(ArchiveMonthlyReview.conclusionToJson)
        .toList(),
    'uncertaintyNote': uncertaintyNote,
  };

  static ArchiveMilestoneReview? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final threshold = (json['milestoneThreshold'] as num?)?.toInt();
    final hash = json['archiveHash']?.toString() ?? '';
    final at = DateTime.tryParse(json['generatedAt']?.toString() ?? '');
    final headline = json['headline']?.toString() ?? '';
    final narrative = json['narrative']?.toString() ?? '';
    final note = json['uncertaintyNote']?.toString() ?? '';
    if (threshold == null || hash.isEmpty || at == null) return null;
    if (headline.isEmpty || narrative.isEmpty || note.isEmpty) return null;

    final primary = ArchiveSynthesisConclusion.fromJson(
      json['primaryTheorySummary'] is Map
          ? Map<String, dynamic>.from(json['primaryTheorySummary'] as Map)
          : null,
    );

    final highlights = <ArchiveSynthesisConclusion>[];
    final raw = json['changeHighlights'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final c = ArchiveSynthesisConclusion.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (c != null) highlights.add(c);
      }
    }

    return ArchiveMilestoneReview(
      milestoneThreshold: threshold,
      eligibleCount: (json['eligibleCount'] as num?)?.toInt() ?? 0,
      archiveHash: hash,
      generatedAt: at,
      model: json['model']?.toString() ?? '',
      headline: headline,
      narrative: narrative,
      primaryTheorySummary: primary,
      changeHighlights: highlights,
      uncertaintyNote: note,
    );
  }
}

/// Deep Dive narrative — does not alter deterministic scores.
class ArchiveDeepDiveNarrative {
  const ArchiveDeepDiveNarrative({
    required this.beliefStatement,
    required this.archiveHash,
    required this.generatedAt,
    required this.model,
    required this.narrativeExplanation,
    required this.evidenceSynthesis,
    required this.beliefEvolutionSummary,
    required this.uncertaintyNote,
  });

  final String beliefStatement;
  final String archiveHash;
  final DateTime generatedAt;
  final String model;
  final String narrativeExplanation;
  final List<ArchiveSynthesisConclusion> evidenceSynthesis;
  final ArchiveSynthesisConclusion beliefEvolutionSummary;
  final String uncertaintyNote;

  static ArchiveDeepDiveNarrative? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final statement = json['beliefStatement']?.toString() ?? '';
    final hash = json['archiveHash']?.toString() ?? '';
    final at = DateTime.tryParse(json['generatedAt']?.toString() ?? '');
    final narrative = json['narrativeExplanation']?.toString() ?? '';
    final note = json['uncertaintyNote']?.toString() ?? '';
    if (statement.isEmpty || hash.isEmpty || at == null) return null;
    if (narrative.isEmpty || note.isEmpty) return null;

    final evolution = ArchiveSynthesisConclusion.fromJson(
      json['beliefEvolutionSummary'] is Map
          ? Map<String, dynamic>.from(json['beliefEvolutionSummary'] as Map)
          : null,
    );
    if (evolution == null) return null;

    final synthesis = <ArchiveSynthesisConclusion>[];
    final raw = json['evidenceSynthesis'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final c = ArchiveSynthesisConclusion.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (c != null) synthesis.add(c);
      }
    }

    return ArchiveDeepDiveNarrative(
      beliefStatement: statement,
      archiveHash: hash,
      generatedAt: at,
      model: json['model']?.toString() ?? '',
      narrativeExplanation: narrative,
      evidenceSynthesis: synthesis,
      beliefEvolutionSummary: evolution,
      uncertaintyNote: note,
    );
  }
}

/// Archive Historian — "What changed in your life?"
class ArchiveHistorianReport {
  const ArchiveHistorianReport({
    required this.monthKey,
    required this.archiveHash,
    required this.eligibleCount,
    required this.generatedAt,
    required this.model,
    required this.title,
    required this.timeline,
    required this.uncertaintyNote,
  });

  final String monthKey;
  final String archiveHash;
  final int eligibleCount;
  final DateTime generatedAt;
  final String model;
  final String title;
  final List<ArchiveSynthesisConclusion> timeline;
  final String uncertaintyNote;

  bool get hasContent => timeline.isNotEmpty;

  static ArchiveHistorianReport? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final monthKey = json['monthKey']?.toString() ?? '';
    final hash = json['archiveHash']?.toString() ?? '';
    final at = DateTime.tryParse(json['generatedAt']?.toString() ?? '');
    final title = json['title']?.toString() ?? '';
    final note = json['uncertaintyNote']?.toString() ?? '';
    if (monthKey.isEmpty || hash.isEmpty || at == null) return null;
    if (title.isEmpty || note.isEmpty) return null;

    final timeline = <ArchiveSynthesisConclusion>[];
    final raw = json['timeline'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final c = ArchiveSynthesisConclusion.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (c != null) timeline.add(c);
      }
    }
    if (timeline.isEmpty) return null;

    return ArchiveHistorianReport(
      monthKey: monthKey,
      archiveHash: hash,
      eligibleCount: (json['eligibleCount'] as num?)?.toInt() ?? 0,
      generatedAt: at,
      model: json['model']?.toString() ?? '',
      title: title,
      timeline: timeline,
      uncertaintyNote: note,
    );
  }
}

class ArchiveSynthesisApiResponse {
  const ArchiveSynthesisApiResponse({
    required this.synthesisType,
    required this.cached,
    this.monthlyReview,
    this.milestoneReview,
    this.deepDiveNarrative,
    this.historianReport,
  });

  final String synthesisType;
  final bool cached;
  final ArchiveMonthlyReview? monthlyReview;
  final ArchiveMilestoneReview? milestoneReview;
  final ArchiveDeepDiveNarrative? deepDiveNarrative;
  final ArchiveHistorianReport? historianReport;
}