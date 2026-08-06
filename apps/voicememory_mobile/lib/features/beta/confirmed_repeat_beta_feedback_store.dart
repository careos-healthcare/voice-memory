import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'confirmed_repeat_beta_feedback_models.dart';

/// Local-only confirmed-repeat beta feedback — never uploads journal text.
class ConfirmedRepeatBetaFeedbackStore {
  ConfirmedRepeatBetaFeedbackStore(this._prefs);

  static const _prefsKey = 'confirmedRepeatBetaFeedback_v1';

  final MobilePrefsStore _prefs;

  static ConfirmedRepeatBetaFeedbackState _cached =
      ConfirmedRepeatBetaFeedbackState.empty;
  static bool _loaded = false;

  static ConfirmedRepeatBetaFeedbackState get cached => _cached;

  static ConfirmedRepeatBetaFeedbackStore instance() =>
      ConfirmedRepeatBetaFeedbackStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().load();
    _loaded = true;
  }

  Future<ConfirmedRepeatBetaFeedbackState> load() async {
    final raw = await _prefs.readMap(_prefsKey);
    return ConfirmedRepeatBetaFeedbackState.fromJson(raw);
  }

  Future<void> save(ConfirmedRepeatBetaFeedbackState state) async {
    final next = state.copyWith(updatedAt: DateTime.now().toUtc());
    await _prefs.writeMap(_prefsKey, next.toJson());
    _cached = next;
    _loaded = true;
  }

  Future<void> dismiss() async {
    final current = await load();
    await save(current.copyWith(dismissed: true));
  }

  Future<void> saveResponse({
    required ConfirmedRepeatBetaFeedbackChoice choice,
    ConfirmedRepeatBetaFeedbackReason? reason,
  }) async {
    final current = await load();
    await save(
      current.copyWith(
        choice: choice,
        reason: reason,
        clearNote: true,
        dismissed: false,
      ),
    );
  }

  static Future<void> resetPersistedState() async {
    _cached = ConfirmedRepeatBetaFeedbackState.empty;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(_prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest() => resetPersistedState();
}
