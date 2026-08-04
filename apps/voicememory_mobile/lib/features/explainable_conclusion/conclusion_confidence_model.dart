import 'change_dimensions.dart';
import 'explainable_conclusion.dart';

/// Fixed, inspectable signals that produce a conclusion's confidence.
///
/// No production engine may assign a confidence literal. Every value is
/// derived here from evidence the user can open and check, so two conclusions
/// with the same evidence always receive the same confidence.
class ConclusionConfidenceSignals {
  const ConclusionConfidenceSignals({
    required this.citationsValid,
    required this.distinctSourceCount,
    required this.threadAligned,
    required this.comparableDimensionCount,
    required this.agreeingDimensionCount,
    required this.chronologyOrdered,
    required this.specificityScore,
    required this.userConfirmedThread,
    required this.userCorrectedFraming,
    required this.ambiguous,
    required this.conflictingEvidence,
  });

  /// Every citation resolved to an exact span of a live transcript.
  final bool citationsValid;

  /// Distinct saved moments supporting the claim.
  final int distinctSourceCount;

  /// The sources belong to the same subject thread.
  final bool threadAligned;

  /// Dimensions both moments actually speak to.
  final int comparableDimensionCount;

  /// Comparable dimensions that point the same way.
  final int agreeingDimensionCount;

  /// Then genuinely precedes Now.
  final bool chronologyOrdered;

  /// 0..1 — how concrete the cited words are versus filler.
  final double specificityScore;

  /// The user named or approved this thread.
  final bool userConfirmedThread;

  /// The user previously said this framing was the wrong angle.
  final bool userCorrectedFraming;

  /// The evidence permits more than one equally supported reading.
  final bool ambiguous;

  /// The evidence points in opposing directions on the same reading.
  final bool conflictingEvidence;

  static const _base = 30;

  /// Derived confidence in 0..100. Zero means "do not show this at all".
  int get value {
    if (!citationsValid || distinctSourceCount == 0) return 0;
    if (conflictingEvidence) return 0;
    var score = _base;
    score += switch (distinctSourceCount) {
      1 => 10,
      2 => 22,
      3 => 30,
      _ => 34,
    };
    if (threadAligned) score += 8;
    if (userConfirmedThread) score += 6;
    if (chronologyOrdered) score += 6;
    if (comparableDimensionCount > 0) {
      score += (comparableDimensionCount.clamp(0, 3) * 4);
      score += (agreeingDimensionCount.clamp(0, 3) * 3);
    }
    score += (specificityScore.clamp(0, 1) * 12).round();
    if (ambiguous) score -= 14;
    if (userCorrectedFraming) score -= 10;
    return score.clamp(0, 95);
  }

  EvidenceConfidenceBand get band {
    final confidence = value;
    if (confidence >= 80 && distinctSourceCount >= 3 && !ambiguous) {
      return EvidenceConfidenceBand.stronglySupported;
    }
    if (distinctSourceCount >= 2) {
      return EvidenceConfidenceBand.repeatedAcrossMoments;
    }
    if (confidence >= 55) {
      return EvidenceConfidenceBand.someSupportingEvidence;
    }
    return EvidenceConfidenceBand.earlyObservation;
  }

  /// Reader-facing uncertainty, phrased from the same signals.
  String get uncertaintyNote {
    if (distinctSourceCount < 2) {
      return 'One saved moment can support an observation, but it cannot show '
          'a pattern or a change on its own.';
    }
    if (ambiguous) {
      return 'These moments can be read more than one way, so ArchiveMe is '
          'holding this comparison open rather than settling it.';
    }
    if (comparableDimensionCount <= 1) {
      return 'Only one thing was directly comparable between these moments, '
          'so the rest of the picture is still open.';
    }
    return 'Two moments can support a comparison, but they cannot establish a '
        'lasting change on their own.';
  }
}

abstract final class ConclusionConfidenceModel {
  /// How concrete the cited words are. Filler-heavy quotes score lower.
  static double specificityOf(Iterable<String> quotes) {
    final tokens = <String>[];
    for (final quote in quotes) {
      tokens.addAll(
        _word
            .allMatches(quote.toLowerCase())
            .map((match) => match.group(0)!)
            .toList(growable: false),
      );
    }
    if (tokens.isEmpty) return 0;
    final concrete = tokens
        .where((token) => token.length >= 4 && !_filler.contains(token))
        .length;
    return (concrete / tokens.length).clamp(0, 1);
  }

  static ConclusionConfidenceSignals forComparison({
    required ChangeDimensions dimensions,
    required Iterable<String> quotes,
    required int distinctSourceCount,
    required bool citationsValid,
    required bool chronologyOrdered,
    required bool threadAligned,
    bool isComparative = true,
    bool userConfirmedThread = false,
    bool userCorrectedFraming = false,
  }) {
    final comparable = dimensions.movements.length;
    final agreeing = dimensions.consistent.length;
    return ConclusionConfidenceSignals(
      citationsValid: citationsValid,
      distinctSourceCount: distinctSourceCount,
      threadAligned: threadAligned,
      comparableDimensionCount: comparable,
      agreeingDimensionCount: agreeing,
      chronologyOrdered: chronologyOrdered,
      specificityScore: specificityOf(quotes),
      userConfirmedThread: userConfirmedThread,
      userCorrectedFraming: userCorrectedFraming,
      ambiguous:
          isComparative &&
          (comparable == 0 || dimensions.sharedSubjectMarkers.isEmpty),
      conflictingEvidence: dimensions.isConflicting,
    );
  }

  static final RegExp _word = RegExp(r"[a-z0-9']+");
  static const _filler = {
    'about',
    'actually',
    'also',
    'basically',
    'been',
    'from',
    'have',
    'into',
    'just',
    'kind',
    'like',
    'maybe',
    'really',
    'some',
    'somehow',
    'something',
    'sort',
    'stuff',
    'that',
    'them',
    'then',
    'there',
    'these',
    'they',
    'thing',
    'things',
    'this',
    'those',
    'very',
    'well',
    'what',
    'when',
    'with',
    'your',
  };
}
