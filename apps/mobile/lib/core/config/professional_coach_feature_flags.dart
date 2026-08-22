import 'package:meta/meta.dart';

/// Compile-time gate for professional / coach tier surfaces.
///
/// Default is off until coach billing ships. Enable locally with:
/// `--dart-define=VOICEMEMORY_ENABLE_PROFESSIONAL_COACH=true`
abstract final class ProfessionalCoachFeatureFlags {
  ProfessionalCoachFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_PROFESSIONAL_COACH',
  );

  /// Test-only override — never set in production code.
  @visibleForTesting
  static bool? debugOverride;

  static bool get enableProfessionalCoach =>
      debugOverride ?? _compileTimeDefault;
}