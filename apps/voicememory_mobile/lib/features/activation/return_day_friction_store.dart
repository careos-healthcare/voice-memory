import '../../storage/mobile_prefs_store.dart';
import 'return_day_friction_model.dart';

/// Persists the return-day friction funnel.
///
/// Stage only ever moves forward within one check-in. When a new check-in
/// becomes due (different [checkInId]), the state resets so the next return day
/// starts clean.
class ReturnDayFrictionStore {
  ReturnDayFrictionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'returnDayFriction';

  Future<ReturnDayFrictionState> load() async {
    final raw = await _prefs.readMap(_key);
    return ReturnDayFrictionState.fromJson(raw);
  }

  Future<void> save(ReturnDayFrictionState state) async {
    await _prefs.writeMap(_key, state.toJson());
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }

  Future<ReturnDayFrictionState> _mutate(
    String checkInId,
    ReturnDayFrictionState Function(ReturnDayFrictionState current) change, {
    required ReturnDayFrictionStage atLeast,
  }) async {
    final raw = await _prefs.updateMap(_key, (current) {
      var state = ReturnDayFrictionState.fromJson(current);
      // A new check-in resets the funnel so each return day is measured fresh.
      if (state.checkInId != null && state.checkInId != checkInId) {
        state = ReturnDayFrictionState.empty;
      }
      final next = change(state.copyWith(checkInId: checkInId));
      // Stage only moves forward within the same check-in; after a reset the
      // floor is notDue (index 0), so this collapses to the target stage.
      final targetIndex =
          atLeast.index > state.stage.index ? atLeast.index : state.stage.index;
      return next
          .copyWith(stage: ReturnDayFrictionStage.values[targetIndex])
          .toJson();
    });
    return ReturnDayFrictionState.fromJson(raw);
  }

  Future<ReturnDayFrictionState> markDueShown(String checkInId, {DateTime? at}) {
    final now = at ?? DateTime.now();
    return _mutate(
      checkInId,
      (s) => s.copyWith(dueShownAt: s.dueShownAt ?? now),
      atLeast: ReturnDayFrictionStage.dueShown,
    );
  }

  Future<ReturnDayFrictionState> markAnswerSelected(
    String checkInId,
    String answer, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return _mutate(
      checkInId,
      (s) => s.copyWith(
        dueShownAt: s.dueShownAt ?? now,
        answerSelectedAt: s.answerSelectedAt ?? now,
        selectedAnswer: answer,
      ),
      atLeast: ReturnDayFrictionStage.answerSelected,
    );
  }

  Future<ReturnDayFrictionState> markRecordingStarted(
    String checkInId, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return _mutate(
      checkInId,
      (s) => s.copyWith(recordingStartedAt: s.recordingStartedAt ?? now),
      atLeast: ReturnDayFrictionStage.recordingStarted,
    );
  }

  Future<ReturnDayFrictionState> markMomentSaved(
    String checkInId, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return _mutate(
      checkInId,
      (s) => s.copyWith(momentSavedAt: s.momentSavedAt ?? now),
      atLeast: ReturnDayFrictionStage.momentSaved,
    );
  }

  Future<ReturnDayFrictionState> markLoopClosed(
    String checkInId, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return _mutate(
      checkInId,
      (s) => s.copyWith(
        momentSavedAt: s.momentSavedAt ?? now,
        loopClosedAt: s.loopClosedAt ?? now,
      ),
      atLeast: ReturnDayFrictionStage.loopClosed,
    );
  }
}
