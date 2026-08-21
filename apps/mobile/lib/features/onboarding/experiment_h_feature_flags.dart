import 'package:meta/meta.dart';

/// Compile-time gate for Experiment H ("Not ChatGPT") onboarding proof.
///
/// Enable locally or in A/B builds with:
/// `--dart-define=VOICEMEMORY_EXPERIMENT_H_ONBOARDING=true`
abstract final class ExperimentHFeatureFlags {
  ExperimentHFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_EXPERIMENT_H_ONBOARDING',
  );

  @visibleForTesting
  static bool? debugOverride;

  static bool get isEnabled => debugOverride ?? _compileTimeDefault;
}