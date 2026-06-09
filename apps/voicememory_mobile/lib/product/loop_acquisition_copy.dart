import '../features/acquisition/acquisition_cohort_model.dart';

/// Structured landing / distribution copy for loop acquisition wedges.
class LoopAcquisitionVariant {
  const LoopAcquisitionVariant({
    required this.id,
    required this.headline,
    required this.subheadline,
    required this.bullets,
    required this.cta,
    this.cohortRoutePath,
    this.isPrimaryWedge = false,
  });

  final String id;
  final String headline;
  final String subheadline;
  final List<String> bullets;
  final String cta;

  /// Internal TestFlight in-app route — not a public deep link.
  final String? cohortRoutePath;
  final bool isPrimaryWedge;
}

/// Loop-specific landing copy — prove_enough is the primary wedge.
abstract final class LoopAcquisitionCopy {
  LoopAcquisitionCopy._();

  static const proveEnough = LoopAcquisitionVariant(
    id: 'prove_enough',
    headline: 'Catch the moment you do more to feel enough.',
    subheadline:
        'ArchiveMe helps you record short moments and test whether your proving-enough loop keeps repeating.',
    bullets: [
      'Spot when stopping feels unsafe',
      'See whether effort comes from choice or pressure',
      'Build a 3-moment evidence trail',
      'Review whether the loop is getting clearer',
    ],
    cta: 'Start the proving-enough loop',
    cohortRoutePath: '/start/prove-enough',
    isPrimaryWedge: true,
  );

  static const capacityYes = LoopAcquisitionVariant(
    id: 'capacity_yes',
    headline: 'Catch the moment you say yes before checking capacity.',
    subheadline:
        'ArchiveMe helps you record short moments and test whether your yes-before-capacity loop keeps repeating.',
    bullets: [
      'Spot when you agree before checking your room',
      'See what the yes seemed to cost',
      'Build a 3-moment evidence trail',
      'Review whether the loop is getting clearer',
    ],
    cta: 'Start the yes-before-capacity loop',
    cohortRoutePath: '/start/capacity-yes',
  );

  static const generic = LoopAcquisitionVariant(
    id: 'generic',
    headline: 'Catch the loop where doing more never feels like enough.',
    subheadline:
        'Record short moments. ArchiveMe helps you test whether pressure, productivity, and enoughness keep repeating.',
    bullets: [],
    cta: 'Start with one moment',
    cohortRoutePath: '/start/prove-enough',
  );

  static const all = [proveEnough, capacityYes, generic];

  static LoopAcquisitionVariant get primaryWedge => proveEnough;

  static LoopAcquisitionVariant? forCohort(AcquisitionCohortId cohortId) {
    switch (cohortId) {
      case AcquisitionCohortId.proveEnoughDirect:
        return proveEnough;
      case AcquisitionCohortId.capacityYesDirect:
        return capacityYes;
      case AcquisitionCohortId.genericArchive:
      case AcquisitionCohortId.unknown:
        return generic;
    }
  }

  static LoopAcquisitionVariant? forId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final variant in all) {
      if (variant.id == id) return variant;
    }
    return null;
  }
}
