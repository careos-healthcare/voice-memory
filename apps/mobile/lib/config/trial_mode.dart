import 'package:archiveme_mobile/config/screenshot_mode.dart' show ScreenshotMode;
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show ScreenshotMode;

/// 5-user activation trial — compile with
/// `--dart-define=ARCHIVEME_TRIAL_MODE=true`
///
/// Separate from [ScreenshotMode] (marketing captures).
abstract class TrialMode {
  TrialMode._();

  static const bool enabled = bool.fromEnvironment(
    'ARCHIVEME_TRIAL_MODE',
  );

  /// Local-only trial: no cloud sync, billing, push, or login required.
  static bool get isLocalOnly => enabled;

  /// Hide developer / QA surfaces from the normal participant flow.
  static bool get hideDeveloperSurfaces => enabled;
}