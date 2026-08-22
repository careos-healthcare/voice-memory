import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/activation/return_day_friction_model.dart';
import 'package:archiveme_mobile/features/activation/return_day_friction_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Drives the return-day flow: open app -> see yesterday's question -> tap
/// answer -> record one short moment -> loop closed. Wraps the store and
/// reports funnel metrics so the team can see where returning users stall.
abstract class ReturnDayFrictionCoordinator {
  ReturnDayFrictionCoordinator._();

  static ReturnDayFrictionStore _store() =>
      ReturnDayFrictionStore(AppServices.instance.prefs);

  /// Current return-day state. Honors screenshot overrides for captures.
  static Future<ReturnDayFrictionState> load() async {
    if (ScreenshotMode.enabled && ScreenshotMode.returnDayStage != null) {
      return ScreenshotSampleData.returnDayStateFor(
        ScreenshotMode.returnDayStage!,
      );
    }
    if (!AppServices.isInitialized) return ReturnDayFrictionState.empty;
    return _store().load();
  }

  static Future<void> clear() async {
    if (!AppServices.isInitialized) return;
    await _store().clear();
  }

  static Future<ReturnDayFrictionState> markDueShown(String checkInId) async {
    if (!AppServices.isInitialized) return ReturnDayFrictionState.empty;
    final before = await _store().load();
    final after = await _store().markDueShown(checkInId);
    if (_reached(before, after, ReturnDayFrictionStage.dueShown)) {
      ActivationTracker.trackReturnDayDueShown();
    }
    return after;
  }

  static Future<ReturnDayFrictionState> markAnswerSelected(
    String checkInId,
    String answer,
  ) async {
    if (!AppServices.isInitialized) return ReturnDayFrictionState.empty;
    final before = await _store().load();
    final after = await _store().markAnswerSelected(checkInId, answer);
    if (_reached(before, after, ReturnDayFrictionStage.answerSelected)) {
      ActivationTracker.trackReturnDayAnswerSelected();
    }
    return after;
  }

  static Future<ReturnDayFrictionState> markRecordingStarted(
    String checkInId,
  ) async {
    if (!AppServices.isInitialized) return ReturnDayFrictionState.empty;
    final before = await _store().load();
    final after = await _store().markRecordingStarted(checkInId);
    if (_reached(before, after, ReturnDayFrictionStage.recordingStarted)) {
      ActivationTracker.trackReturnDayRecordingStarted();
    }
    return after;
  }

  static Future<ReturnDayFrictionState> markMomentSaved(
    String checkInId,
  ) async {
    if (!AppServices.isInitialized) return ReturnDayFrictionState.empty;
    final before = await _store().load();
    final after = await _store().markMomentSaved(checkInId);
    if (_reached(before, after, ReturnDayFrictionStage.momentSaved)) {
      ActivationTracker.trackReturnDayMomentSaved();
    }
    return after;
  }

  /// Final step: the return-day loop is closed. This is the payoff endpoint.
  static Future<ReturnDayFrictionState> markLoopClosed(String checkInId) async {
    if (!AppServices.isInitialized) return ReturnDayFrictionState.empty;
    final before = await _store().load();
    final after = await _store().markLoopClosed(checkInId);
    if (_reached(before, after, ReturnDayFrictionStage.momentSaved)) {
      ActivationTracker.trackReturnDayMomentSaved();
    }
    if (_reached(before, after, ReturnDayFrictionStage.loopClosed)) {
      ActivationTracker.trackReturnDayLoopClosed();
    }
    return after;
  }

  /// Call when leaving the return-day flow. Fires once if the user picked an
  /// answer but never recorded a moment, so we can see answer-to-record drop.
  static Future<void> trackAbandonedAfterAnswerIfPending() async {
    if (!AppServices.isInitialized) return;
    final state = await _store().load();
    final answeredButNotRecorded =
        state.stage == ReturnDayFrictionStage.answerSelected ||
        state.stage == ReturnDayFrictionStage.recordingStarted;
    if (answeredButNotRecorded) {
      ActivationTracker.trackReturnDayAbandonedAfterAnswer();
    }
  }

  static bool _reached(
    ReturnDayFrictionState before,
    ReturnDayFrictionState after,
    ReturnDayFrictionStage stage,
  ) {
    // A new check-in resets the funnel, so a different id always counts as a
    // fresh crossing of the stage boundary.
    final crossedWithinSame =
        before.checkInId == after.checkInId &&
        before.stage.index < stage.index &&
        after.stage.index >= stage.index;
    final freshCheckIn =
        before.checkInId != after.checkInId && after.stage.index >= stage.index;
    return crossedWithinSame || freshCheckIn;
  }
}