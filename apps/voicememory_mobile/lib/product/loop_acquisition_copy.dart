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
abstract class LoopAcquisitionCopy {
  LoopAcquisitionCopy._();

  static const wedgeRoutePromise =
      'Save the moments where this happens. See whether it repeats.';

  static const proveEnough = LoopAcquisitionVariant(
    id: 'prove_enough',
    headline: 'Catch the moment you do more to feel enough.',
    subheadline: wedgeRoutePromise,
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
    headline: 'Catch the yes before it costs you.',
    subheadline: wedgeRoutePromise,
    bullets: [
      'Save a yes moment',
      'See what pulled you in',
      'Review what changed',
    ],
    cta: 'Save yes moment',
    cohortRoutePath: '/start/capacity-yes',
  );

  static const generic = LoopAcquisitionVariant(
    id: 'generic',
    headline: 'When it repeats, save it',
    subheadline:
        'Save one real moment when something stands out. ArchiveMe compares it later.',
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
