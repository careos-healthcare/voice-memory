import 'beta_proof_lift_copy.dart';

enum BetaProofLiftSurface {
  timelineProofMoment,
  firstProofPayoff,
  patterns,
}

extension BetaProofLiftSurfaceAnalytics on BetaProofLiftSurface {
  String get analyticsValue => switch (this) {
        BetaProofLiftSurface.timelineProofMoment => 'timeline_proof_moment',
        BetaProofLiftSurface.firstProofPayoff => 'first_proof_payoff',
        BetaProofLiftSurface.patterns => 'patterns',
      };

  String get betaFeedbackSurfaceValue => switch (this) {
        BetaProofLiftSurface.timelineProofMoment => 'timeline_proof_moment',
        BetaProofLiftSurface.firstProofPayoff => 'first_proof_payoff',
        BetaProofLiftSurface.patterns => 'timeline_proof_moment',
      };
}

class BetaProofLiftSection {
  const BetaProofLiftSection({
    required this.heading,
    required this.body,
  });

  final String heading;
  final String body;
}

class BetaProofLiftResult {
  const BetaProofLiftResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.surface,
    required this.title,
    required this.body,
    required this.sections,
    required this.deltaRows,
    required this.hasSafeAnchor,
    required this.hasDelta,
    required this.hasCurrentRelevance,
    required this.hasCorrection,
  });

  factory BetaProofLiftResult.hidden({
    required String source,
    required BetaProofLiftSurface surface,
    required int entryCount,
  }) =>
      BetaProofLiftResult(
        shouldShow: false,
        entryCount: entryCount,
        source: source,
        surface: surface,
        title: BetaProofLiftCopy.title,
        body: BetaProofLiftCopy.body,
        sections: const [],
        deltaRows: const [],
        hasSafeAnchor: false,
        hasDelta: false,
        hasCurrentRelevance: false,
        hasCorrection: false,
      );

  final bool shouldShow;
  final int entryCount;
  final String source;
  final BetaProofLiftSurface surface;
  final String title;
  final String body;
  final List<BetaProofLiftSection> sections;
  final List<String> deltaRows;
  final bool hasSafeAnchor;
  final bool hasDelta;
  final bool hasCurrentRelevance;
  final bool hasCorrection;

  List<String> get allCopyStrings => [
        title,
        body,
        ...sections.expand((section) => [section.heading, section.body]),
        ...deltaRows,
      ];
}
