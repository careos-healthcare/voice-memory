/// 5-user activation trial — compile with
/// `--dart-define=ARCHIVEME_TRIAL_MODE=true`
///
/// Separate from [ScreenshotMode] (marketing captures).
abstract final class TrialMode {
  TrialMode._();

  static const bool enabled = bool.fromEnvironment(
    'ARCHIVEME_TRIAL_MODE',
    defaultValue: false,
  );

  /// Local-only trial: no cloud sync, billing, push, or login required.
  static bool get isLocalOnly => enabled;

  /// Hide developer / QA surfaces from the normal participant flow.
  static bool get hideDeveloperSurfaces => enabled;
}
