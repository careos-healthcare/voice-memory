import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/activation/first_loop_activation_model.dart';
import 'package:archiveme_mobile/features/activation/first_loop_activation_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Drives the compressed first loop: record one moment -> see first pattern ->
/// choose tomorrow's check. Wraps the store and reports funnel metrics.
abstract class FirstLoopActivationCoordinator {
  FirstLoopActivationCoordinator._();

  static FirstLoopActivationStore _store() =>
      FirstLoopActivationStore(AppServices.instance.prefs);

  /// Current first-loop state. Honors screenshot overrides for captures.
  static Future<FirstLoopActivationState> load() async {
    if (ScreenshotMode.enabled && ScreenshotMode.firstLoopStage != null) {
      return ScreenshotSampleData.firstLoopStateFor(
        ScreenshotMode.firstLoopStage!,
      );
    }
    if (!AppServices.isInitialized) return FirstLoopActivationState.empty;
    return _store().load();
  }

  static Future<void> clear() async {
    if (!AppServices.isInitialized) return;
    await _store().clear();
  }

  static Future<FirstLoopActivationState> markOpenedRecord() async {
    if (!AppServices.isInitialized) return FirstLoopActivationState.empty;
    final before = await _store().load();
    final after = await _store().markOpenedRecord();
    if (_reached(before, after, FirstLoopActivationStage.openedRecord)) {
      ActivationTracker.trackFirstLoopRecordOpened();
    }
    return after;
  }

  static Future<FirstLoopActivationState> markRecordingStarted() async {
    if (!AppServices.isInitialized) return FirstLoopActivationState.empty;
    final before = await _store().load();
    final after = await _store().markRecordingStarted();
    if (_reached(before, after, FirstLoopActivationStage.recordingStarted)) {
      ActivationTracker.trackFirstLoopRecordingStarted();
    }
    return after;
  }

  static Future<FirstLoopActivationState> markFirstMomentSaved() async {
    if (!AppServices.isInitialized) return FirstLoopActivationState.empty;
    final before = await _store().load();
    final after = await _store().markFirstMomentSaved();
    if (_reached(before, after, FirstLoopActivationStage.firstMomentSaved)) {
      ActivationTracker.trackFirstLoopMomentSaved();
    }
    return after;
  }

  static Future<FirstLoopActivationState> markFirstPatternShown(
    String title,
  ) async {
    if (!AppServices.isInitialized) return FirstLoopActivationState.empty;
    final before = await _store().load();
    final after = await _store().markFirstPatternShown(title);
    if (_reached(before, after, FirstLoopActivationStage.firstPatternShown)) {
      ActivationTracker.trackFirstLoopPatternShown();
    }
    return after;
  }

  static Future<FirstLoopActivationState> markTomorrowCheckChosen(
    String question,
  ) async {
    if (!AppServices.isInitialized) return FirstLoopActivationState.empty;
    final before = await _store().load();
    final after = await _store().markTomorrowCheckChosen(question);
    if (_reached(before, after, FirstLoopActivationStage.tomorrowCheckChosen)) {
      ActivationTracker.trackFirstLoopTomorrowCheckChosen();
    }
    return after;
  }

  /// Final step: the loop is set for tomorrow. This is the emotional endpoint
  /// of the first session.
  static Future<FirstLoopActivationState> markLoopReady({
    required String patternTitle,
    required String tomorrowQuestion,
  }) async {
    if (!AppServices.isInitialized) return FirstLoopActivationState.empty;
    final before = await _store().load();
    // Record the chosen-check transition too, so funnel counts stay coherent
    // even when a user goes straight from pattern shown to loop ready.
    final after = await _store().markLoopReady(patternTitle, tomorrowQuestion);
    if (_reached(before, after, FirstLoopActivationStage.tomorrowCheckChosen)) {
      ActivationTracker.trackFirstLoopTomorrowCheckChosen();
    }
    if (_reached(before, after, FirstLoopActivationStage.loopReady)) {
      ActivationTracker.trackFirstLoopReady();
    }
    return after;
  }

  static bool _reached(
    FirstLoopActivationState before,
    FirstLoopActivationState after,
    FirstLoopActivationStage stage,
  ) {
    return before.stage.index < stage.index && after.stage.index >= stage.index;
  }
}