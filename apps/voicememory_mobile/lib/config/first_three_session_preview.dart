import 'screenshot_mode.dart';

/// QA preview for the first-three-session loop.
///
/// Run with:
/// `--dart-define=FIRST_THREE_SESSION_PREVIEW=1` (session 1 / one entry)
/// `--dart-define=FIRST_THREE_SESSION_PREVIEW=2` (session 2 / two entries)
/// `--dart-define=FIRST_THREE_SESSION_PREVIEW=3` (session 3 / three entries)
///
/// Also respects `VOICE_MEMORY_SCREENSHOT_MODE=true` with
/// `VOICE_MEMORY_SCREENSHOT_JOURNEY_STEP=0|1|2|3`.
abstract class FirstThreeSessionPreview {
  FirstThreeSessionPreview._();

  static const String _raw = String.fromEnvironment(
    'FIRST_THREE_SESSION_PREVIEW',
    defaultValue: '',
  );

  static int? get forcedSession {
    final direct = int.tryParse(_raw.trim());
    if (direct != null && direct >= 1 && direct <= 3) return direct;
    final journey = ScreenshotMode.screenshotJourneyReflectionCount;
    if (journey < 0) return null;
    if (journey == 0) return 1;
    if (journey == 1) return 2;
    if (journey == 2) return 3;
    if (journey >= 3) return 3;
    return null;
  }

  static int reflectionCountForForcedSession(int session) {
    switch (session.clamp(1, 3)) {
      case 1:
        return 1;
      case 2:
        return 2;
      default:
        return 3;
    }
  }

  static int? get forcedReflectionCount {
    final session = forcedSession;
    if (session == null) return null;
    return reflectionCountForForcedSession(session);
  }
}
