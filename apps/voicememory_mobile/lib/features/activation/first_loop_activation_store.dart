import '../../storage/mobile_prefs_store.dart';
import 'first_loop_activation_model.dart';

/// Persists the compressed first-loop activation state.
///
/// Stage only ever moves forward: a later session cannot drag a user back to an
/// earlier step.
class FirstLoopActivationStore {
  FirstLoopActivationStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'firstLoopActivation';

  Future<FirstLoopActivationState> load() async {
    final raw = await _prefs.readMap(_key);
    return FirstLoopActivationState.fromJson(raw);
  }

  Future<void> save(FirstLoopActivationState state) async {
    await _prefs.writeMap(_key, state.toJson());
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }

  Future<FirstLoopActivationState> _mutate(
    FirstLoopActivationState Function(FirstLoopActivationState current) change, {
    required FirstLoopActivationStage atLeast,
  }) async {
    final raw = await _prefs.updateMap(_key, (current) {
      final state = FirstLoopActivationState.fromJson(current);
      final next = change(state);
      // Stage only moves forward: max(current, target).
      final targetIndex =
          atLeast.index > state.stage.index ? atLeast.index : state.stage.index;
      return next
          .copyWith(stage: FirstLoopActivationStage.values[targetIndex])
          .toJson();
    });
    return FirstLoopActivationState.fromJson(raw);
  }

  Future<FirstLoopActivationState> markOpenedRecord({DateTime? at}) {
    final now = at ?? DateTime.now();
    return _mutate(
      (s) => s.copyWith(openedAt: s.openedAt ?? now),
      atLeast: FirstLoopActivationStage.openedRecord,
    );
  }

  Future<FirstLoopActivationState> markRecordingStarted({DateTime? at}) {
    final now = at ?? DateTime.now();
    return _mutate(
      (s) => s.copyWith(
        openedAt: s.openedAt ?? now,
        firstRecordingStartedAt: s.firstRecordingStartedAt ?? now,
      ),
      atLeast: FirstLoopActivationStage.recordingStarted,
    );
  }

  Future<FirstLoopActivationState> markFirstMomentSaved({DateTime? at}) {
    final now = at ?? DateTime.now();
    return _mutate(
      (s) => s.copyWith(
        openedAt: s.openedAt ?? now,
        firstMomentSavedAt: s.firstMomentSavedAt ?? now,
      ),
      atLeast: FirstLoopActivationStage.firstMomentSaved,
    );
  }

  Future<FirstLoopActivationState> markFirstPatternShown(
    String title, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return _mutate(
      (s) => s.copyWith(
        firstPatternShownAt: s.firstPatternShownAt ?? now,
        firstPatternTitle: s.firstPatternTitle ?? title,
      ),
      atLeast: FirstLoopActivationStage.firstPatternShown,
    );
  }

  Future<FirstLoopActivationState> markTomorrowCheckChosen(
    String question, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return _mutate(
      (s) => s.copyWith(
        tomorrowCheckChosenAt: s.tomorrowCheckChosenAt ?? now,
        tomorrowQuestion: question,
      ),
      atLeast: FirstLoopActivationStage.tomorrowCheckChosen,
    );
  }

  Future<FirstLoopActivationState> markLoopReady(
    String title,
    String question, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return _mutate(
      (s) => s.copyWith(
        tomorrowCheckChosenAt: s.tomorrowCheckChosenAt ?? now,
        completedAt: s.completedAt ?? now,
        firstPatternTitle: s.firstPatternTitle ?? title,
        tomorrowQuestion: question,
      ),
      atLeast: FirstLoopActivationStage.loopReady,
    );
  }
}
