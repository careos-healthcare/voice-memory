/// Theory tracker models aligned with web [Theory] / [TheoryTrackerReport].
import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';

enum TheoryStatus { active, strengthening, weakening, resolved, retired }

enum TheoryFeedbackReaction {
  feelsTrue,
  partlyTrue,
  notTrue,
  tooObvious,
  surprising,
}

class TheoryEvidenceQuote {
  const TheoryEvidenceQuote({
    required this.entryId,
    required this.dateLabel,
    required this.quote,
    this.audioId,
    this.startTimestampMs,
    this.endTimestampMs,
    this.chunkId,
  });

  final String entryId;
  final String dateLabel;
  final String quote;
  final String? audioId;
  final int? startTimestampMs;
  final int? endTimestampMs;
  final String? chunkId;

  bool get hasCitationPlayback =>
      audioId != null &&
      audioId!.isNotEmpty &&
      startTimestampMs != null &&
      endTimestampMs != null &&
      endTimestampMs! > startTimestampMs!;

  TheoryEvidenceQuote copyWith({
    String? entryId,
    String? dateLabel,
    String? quote,
    String? audioId,
    int? startTimestampMs,
    int? endTimestampMs,
    String? chunkId,
  }) {
    return TheoryEvidenceQuote(
      entryId: entryId ?? this.entryId,
      dateLabel: dateLabel ?? this.dateLabel,
      quote: quote ?? this.quote,
      audioId: audioId ?? this.audioId,
      startTimestampMs: startTimestampMs ?? this.startTimestampMs,
      endTimestampMs: endTimestampMs ?? this.endTimestampMs,
      chunkId: chunkId ?? this.chunkId,
    );
  }
}

class TrackedTheory {
  const TrackedTheory({
    required this.id,
    required this.statement,
    required this.confidence,
    required this.confidenceDelta, required this.supportingEvidenceCount, required this.contradictingEvidenceCount, required this.createdAt, required this.updatedAt, required this.status, required this.supportingEvidence, required this.contradictingEvidence,     required this.whatChanged, required this.source, this.previousConfidence,
    this.resolutionNote,
    this.inspection,
  });

  final String id;
  final String statement;
  final int confidence;
  final int? previousConfidence;
  final int confidenceDelta;
  final int supportingEvidenceCount;
  final int contradictingEvidenceCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TheoryStatus status;
  final String? resolutionNote;
  final List<TheoryEvidenceQuote> supportingEvidence;
  final List<TheoryEvidenceQuote> contradictingEvidence;
  final List<String> whatChanged;
  final String source;
  final TheoryRankingInspection? inspection;
}

class TheoryTrackerReport {
  const TheoryTrackerReport({
    required this.generatedAt,
    required this.active,
    required this.strengthening,
    required this.weakening,
    required this.resolved,
    required this.retired,
    required this.all,
  });

  final DateTime generatedAt;
  final List<TrackedTheory> active;
  final List<TrackedTheory> strengthening;
  final List<TrackedTheory> weakening;
  final List<TrackedTheory> resolved;
  final List<TrackedTheory> retired;
  final List<TrackedTheory> all;
}

class EvolvingViewSnapshot {
  const EvolvingViewSnapshot({
    required this.totalTheories,
    required this.underReviewCount,
    required this.strengtheningCount,
    required this.weakeningOrResolvedCount,
    this.lastUpdated,
  });

  final int totalTheories;
  final int underReviewCount;
  final int strengtheningCount;
  final int weakeningOrResolvedCount;
  final DateTime? lastUpdated;
}