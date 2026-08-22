import 'package:archiveme_mobile/features/archive_theory/archive_theory_copy.dart' show ArchiveTheoryCopy;

/// User-facing Archive V1 strings.
abstract class ArchiveV1Copy {
  ArchiveV1Copy._();

  /// Superseded in UI by [ArchiveTheoryCopy.heroTitle].
  static const String beliefHeroTitle = 'Possible patterns ArchiveMe is watching';
  static const String evidenceTrailCta = 'View evidence';

  /// Primary CTA on archive hero — opens [/archive-deep-dive].
  static const String showMeWhyCta = 'Show me why';
  static const String evolutionSectionTitle = 'What may have changed';
  static const String thenLabel = 'THEN';
  static const String nowLabel = 'NOW';
  static const String contradictionsTitle =
      'Moments that may not fit';
  static const String blindSpotsTitle = 'What may be missing';
  static const String evidenceTrailScreenTitle = 'Evidence';
  static const String whyBelieves = 'Why does ArchiveMe suggest this?';
}