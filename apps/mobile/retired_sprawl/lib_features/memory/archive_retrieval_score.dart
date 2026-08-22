import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';

/// Archive Retrieval Scoring — how relevant one saved record is to the
/// present, on a stable band scale. Memory should be evidence, not
/// gravity: the archive surfaces only its most recent and related
/// evidence, and old context decays instead of accumulating pull.
///
/// Exact numeric scores are internal only — nothing here is shown to
/// users as a number or percentage.
enum ArchiveRetrievalBand {
  /// No useful signal — the record is not retrieved at all.
  none,

  /// Some signal, not enough for a connection claim on its own.
  weak,

  /// Recent and related enough to support an existing evidence engine.
  possible,

  /// Reserved for retrieval + existing evidence-engine support together.
  /// The retrieval score alone can not produce this band.
  strong,
}

extension ArchiveRetrievalBandId on ArchiveRetrievalBand {
  String get id => switch (this) {
    ArchiveRetrievalBand.none => 'none',
    ArchiveRetrievalBand.weak => 'weak',
    ArchiveRetrievalBand.possible => 'possible',
    ArchiveRetrievalBand.strong => 'strong',
  };

  bool operator >=(ArchiveRetrievalBand other) => index >= other.index;
}

/// One record's retrieval score. Component points are kept separately so
/// tests and the policy can reason about why a record ranked where it did
/// — none of this is user-facing.
class ArchiveRetrievalScore {
  const ArchiveRetrievalScore({
    required this.record,
    required this.recencyPoints,
    required this.relevancePoints,
    required this.usagePoints,
    required this.importancePoints,
    required this.band,
  });

  final PressureCheckInRecord record;

  /// Decay-aware recency: same day strongest, then a gradual step-down.
  final int recencyPoints;

  /// Real overlap with other candidate records: shared context tags,
  /// repeated meaningful words, same pressure option theme.
  final int relevancePoints;

  /// Session usage signals: useful feedback raises, "not quite" lowers.
  final int usagePoints;

  /// Existing safe metadata only (e.g. an explicit chose-to-stop mark).
  final int importancePoints;

  final ArchiveRetrievalBand band;

  int get total =>
      recencyPoints + relevancePoints + usagePoints + importancePoints;
}

/// The scored, capped retrieval result for one engine call.
class ArchiveRetrievalResult {
  const ArchiveRetrievalResult({required this.scores, required this.band});

  const ArchiveRetrievalResult.empty()
    : scores = const [],
      band = ArchiveRetrievalBand.none;

  /// Top relevant records only, strongest first, capped by the engine.
  final List<ArchiveRetrievalScore> scores;

  /// The best band across the returned records, capped at
  /// [ArchiveRetrievalBand.possible] — strong needs evidence support.
  final ArchiveRetrievalBand band;

  List<PressureCheckInRecord> get records =>
      scores.map((s) => s.record).toList();

  bool get isEmpty => scores.isEmpty;

  /// Whether existing evidence engines may build connection claims from
  /// this result at all. Weak-only retrieval can not back a major
  /// memory card.
  bool get supportsConnectionClaims =>
      band == ArchiveRetrievalBand.possible ||
      band == ArchiveRetrievalBand.strong;

  /// The band including existing evidence-engine support: strong is
  /// possible-band retrieval plus an engine that already holds the
  /// evidence — never the retrieval score alone.
  ArchiveRetrievalBand bandWithEvidence({required bool hasEvidenceSupport}) {
    if (band == ArchiveRetrievalBand.possible && hasEvidenceSupport) {
      return ArchiveRetrievalBand.strong;
    }
    return band;
  }
}

/// The only consumer-facing copy this layer can add — high-level scoring
/// explanation lines for the existing "Why this appeared" sheet. No
/// scores, percentages, notes, or snippets.
abstract class ArchiveRetrievalCopy {
  ArchiveRetrievalCopy._();

  static const String whyRecentLine =
      'ArchiveMe found recent and related evidence.';
  static const String whyOlderLine =
      'Older entries are used only when they still seem relevant.';
}