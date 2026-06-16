import '../../config/screenshot_mode.dart';
import '../activation/activation_tracker.dart';
import 'key_moment_engine.dart';
import 'key_moment_model.dart';
import 'key_moment_store.dart';

/// Builds and saves a [KeyMoment] after a reflection save or check-in
/// completion, then tracks the create event. No-op in screenshot mode.
abstract class KeyMomentCoordinator {
  KeyMomentCoordinator._();

  static Future<KeyMoment?> captureAfterSave({
    required String reflectionText,
    DateTime? date,
    String? patternTitle,
    String? resultHint,
    String? nextCheck,
    String? languageCode,
    KeyMomentSource source = KeyMomentSource.reflection,
  }) async {
    if (ScreenshotMode.enabled) return null;
    if (reflectionText.trim().isEmpty) return null;
    try {
      final moment = buildKeyMoment(
        reflectionText: reflectionText,
        date: date ?? DateTime.now(),
        patternTitle: patternTitle,
        resultHint: resultHint,
        nextCheck: nextCheck,
        languageCode: languageCode,
        source: source,
      );
      await KeyMomentStore.instance().save(moment);
      ActivationTracker.trackKeyMomentCreated();
      return moment;
    } catch (_) {
      // Capturing a Key Moment must never break the save/check-in flow.
      return null;
    }
  }
}
