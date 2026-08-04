/// GPT synthesis V4 — explainable narrative over deterministic archive engines.
library;

import '../explainable_conclusion/explainable_conclusion.dart';
import '../ai_engines/models/ai_explainability.dart';

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
    this.quote,
    this.startUtf16,
    this.endUtf16,
    this.audioTimestampMs,
    this.sourceCapturedAt,
    this.sourceType,
    this.confidenceScore = 1,
  });

  final String entryId;
  final String? excerpt;
  final String? role;
  final String? quote;
  final int? startUtf16;
  final int? endUtf16;
  final int? audioTimestampMs;
  final DateTime? sourceCapturedAt;
  final String? sourceType;
  final double confidenceScore;

  String get sourceEntryId => entryId;
  String get exactQuote => quote ?? excerpt ?? '';

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'sourceEntryId': entryId,
    if (excerpt != null) 'excerpt': excerpt,
    if (role != null) 'role': role,
    if (quote != null) 'quote': quote,
    if (quote != null) 'exactQuote': quote,
    if (audioTimestampMs != null) 'audioTimestampMs': audioTimestampMs,
    if (sourceCapturedAt != null)
      'sourceCapturedAt': sourceCapturedAt!.toUtc().toIso8601String(),
    if (sourceType != null) 'sourceType': sourceType,
    'confidenceScore': confidenceScore,
    if (startUtf16 != null) 'startUtf16': startUtf16,
    if (endUtf16 != null) 'endUtf16': endUtf16,
  };

  static ArchiveSynthesisEvidenceRef? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id =
        json['sourceEntryId']?.toString() ?? json['entryId']?.toString() ?? '';
    if (id.isEmpty) return null;
    return ArchiveSynthesisEvidenceRef(
      entryId: id,
      excerpt: json['excerpt']?.toString(),
      role: json['role']?.toString(),
      quote: json['exactQuote']?.toString() ?? json['quote']?.toString(),
      startUtf16: json['startUtf16'] is int ? json['startUtf16'] as int : null,
      endUtf16: json['endUtf16'] is int ? json['endUtf16'] as int : null,
      audioTimestampMs: json['audioTimestampMs'] is int
          ? json['audioTimestampMs'] as int
          : null,
      sourceCapturedAt: DateTime.tryParse(
        json['sourceCapturedAt']?.toString() ?? '',
      )?.toUtc(),
      sourceType: json['sourceType']?.toString(),
      confidenceScore: json['confidenceScore'] is num
          ? (json['confidenceScore'] as num).toDouble()
          : 1,
    );
  }
}

class ArchiveSynthesisConclusion {
  const ArchiveSynthesisConclusion({
    required this.id,
    required this.statement,
    required this.confidencePercent,
    required this.reasoning,
    required this.alternativeExplanation,
    required this.uncertainty,
    required this.uncertaintyNote,
    required this.evidence,
    this.alternatives = const [],
    this.provenance,
    this.isLegacy = false,
    this.confidenceKnown = true,
  });

  final String id;
  final String statement;
  final int confidencePercent;
  final List<String> reasoning;
  final ExplainableAlternative alternativeExplanation;
  final String uncertainty;
  final String uncertaintyNote;
  final List<ArchiveSynthesisEvidenceRef> evidence;
  final List<ExplainableAlternative> alternatives;
  final ExplainableConclusionProvenance? provenance;
  final bool isLegacy;
  final bool confidenceKnown;

  AiExplainability get explainability => isLegacy
      ? AiExplainability.legacy(sourceId: id)
      : AiExplainability(
          confidence: confidencePercent,
          evidence: evidence
              .map(
                (item) => AiEvidenceSource(
                  sourceId: item.entryId,
                  excerpt: item.quote ?? item.excerpt ?? statement,
                  startUtf16: item.startUtf16,
                  endUtf16: item.endUtf16,
                  audioTimestampMs: item.audioTimestampMs,
                  confidenceScore: item.confidenceScore,
                ),
              )
              .toList(),
          reasoning: reasoning,
          alternativeExplanation: alternativeExplanation.statement,
          uncertainty: uncertainty,
        );

  static ArchiveSynthesisConclusion? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString() ?? '';
    final statement = json['statement']?.toString() ?? '';
    if (id.isEmpty || statement.isEmpty) return null;
    final provenance = ExplainableConclusionProvenance.fromJson(
      json['provenance'],
    );
    final isV4 =
        json['legacyMode'] != true &&
        (provenance?.schemaVersion == 4 ||
            json.containsKey('reasoning') ||
            json.containsKey('alternativeExplanation') ||
            json.containsKey('uncertainty'));
    if (!isV4) {
      final rawConfidence = json['confidencePercent'] ?? json['confidence'];
      final knownConfidence =
          rawConfidence is num && json['confidenceKnown'] != false;
      final legacyAlternatives = (json['alternatives'] as List? ?? const [])
          .map(ExplainableAlternative.fromJson)
          .whereType<ExplainableAlternative>()
          .toList();
      final fallbackAlternative = legacyAlternatives.isEmpty
          ? const ExplainableAlternative(
              statement: 'Another interpretation was not stored.',
              rationale:
                  'Legacy synthesis did not preserve contrasting viewpoints.',
            )
          : legacyAlternatives.first;
      return ArchiveSynthesisConclusion(
        id: id,
        statement: statement,
        confidencePercent: knownConfidence
            ? rawConfidence.toInt().clamp(0, 100)
            : 0,
        confidenceKnown: knownConfidence,
        reasoning: const ['Derived from older vault patterns.'],
        alternativeExplanation: fallbackAlternative,
        uncertainty:
            json['uncertaintyNote']?.toString().trim().isNotEmpty == true
            ? json['uncertaintyNote'].toString()
            : 'The original synthesis did not record uncertainty or complete source context.',
        uncertaintyNote:
            json['uncertaintyNote']?.toString().trim().isNotEmpty == true
            ? json['uncertaintyNote'].toString()
            : 'The original synthesis did not record uncertainty or complete source context.',
        evidence: const [],
        alternatives: legacyAlternatives.isEmpty
            ? [fallbackAlternative]
            : legacyAlternatives,
        provenance: provenance,
        isLegacy: true,
      );
    }
    final uncertainty = json['uncertainty']?.toString() ?? '';
    final uncertaintyNote = json['uncertaintyNote']?.toString() ?? '';
    final confidence = json['confidence'];
    final confidencePercent = json['confidencePercent'];
    final reasoning = (json['reasoning'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final primaryAlternative = ExplainableAlternative.fromJson(
      json['alternativeExplanation'],
    );
    if (id.isEmpty ||
        statement.isEmpty ||
        uncertainty.isEmpty ||
        uncertainty != uncertaintyNote ||
        confidence is! int ||
        confidencePercent is! int ||
        confidence != confidencePercent ||
        reasoning.isEmpty ||
        primaryAlternative == null) {
      return null;
    }
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
    final alternatives = (json['alternatives'] as List? ?? const [])
        .map(ExplainableAlternative.fromJson)
        .whereType<ExplainableAlternative>()
        .toList();
    if (alternatives.isEmpty ||
        alternatives.first.statement != primaryAlternative.statement ||
        alternatives.first.reason != primaryAlternative.reason ||
        provenance?.schemaVersion != 4 ||
        provenance?.sourceRevision != 'archive-explainable-v2') {
      return null;
    }
    return ArchiveSynthesisConclusion(
      id: id,
      statement: statement,
      confidencePercent: confidence,
      reasoning: reasoning,
      alternativeExplanation: primaryAlternative,
      uncertainty: uncertainty,
      uncertaintyNote: uncertaintyNote,
      evidence: evidence,
      alternatives: alternatives,
      provenance: provenance,
    );
  }
}

/// Stored Archive Monthly Review (V4).
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
    'reviewVersion': 4,
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
        'confidence': c.confidencePercent,
        'reasoning': c.reasoning,
        'alternativeExplanation': c.alternativeExplanation.toJson(),
        'uncertainty': c.uncertainty,
        'uncertaintyNote': c.uncertaintyNote,
        'evidence': c.evidence.map((e) => e.toJson()).toList(),
        'alternatives': c.alternatives.map((e) => e.toJson()).toList(),
        if (c.provenance != null) 'provenance': c.provenance!.toJson(),
        if (c.isLegacy) 'legacyMode': true,
        if (!c.confidenceKnown) 'confidenceKnown': false,
      };

  static ArchiveMonthlyReview? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    if (!_supportsLegacyReview(json['reviewVersion'])) return null;
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
  final ArchiveSynthesisConclusion primaryTheorySummary;
  final List<ArchiveSynthesisConclusion> changeHighlights;
  final String uncertaintyNote;

  Map<String, dynamic> toJson() => {
    'reviewVersion': 4,
    'milestoneThreshold': milestoneThreshold,
    'eligibleCount': eligibleCount,
    'archiveHash': archiveHash,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'model': model,
    'headline': headline,
    'narrative': narrative,
    'primaryTheorySummary': ArchiveMonthlyReview.conclusionToJson(
      primaryTheorySummary,
    ),
    'changeHighlights': changeHighlights
        .map(ArchiveMonthlyReview.conclusionToJson)
        .toList(),
    'uncertaintyNote': uncertaintyNote,
  };

  static ArchiveMilestoneReview? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    if (!_supportsLegacyReview(json['reviewVersion'])) return null;
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
    if (primary == null) return null;

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
    if (!_supportsLegacyReview(json['reviewVersion'])) return null;
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
    if (!_supportsLegacyReview(json['reviewVersion'])) return null;
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

bool _supportsLegacyReview(Object? version) {
  final parsed = (version as num?)?.toInt();
  return parsed != null && parsed >= 1 && parsed <= 4;
}
