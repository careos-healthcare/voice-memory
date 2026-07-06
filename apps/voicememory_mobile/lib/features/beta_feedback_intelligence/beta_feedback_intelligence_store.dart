import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import 'beta_feedback_intelligence_model.dart';

/// Local-only beta feedback intelligence persistence — no journal content.
abstract final class BetaFeedbackIntelligenceStore {
  BetaFeedbackIntelligenceStore._();

  static const prefsKey = 'betaFeedbackIntelligence_v1';

  static BetaFeedbackIntelligenceState _cached =
      BetaFeedbackIntelligenceState.empty;
  static bool _loaded = false;
  static bool _sessionSubmitted = false;
  static bool _proEvidenceSheetOpenedThisSession = false;

  static BetaFeedbackIntelligenceState get cached => _cached;

  static bool get sessionProEvidenceSheetOpened =>
      _proEvidenceSheetOpenedThisSession;

  @visibleForTesting
  static bool get proEvidenceSheetOpenedThisSession =>
      _proEvidenceSheetOpenedThisSession;

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readMap(prefsKey);
    _cached = BetaFeedbackIntelligenceState.fromJson(raw);
    _loaded = true;
  }

  static bool isSubmittedForSession({DateTime? now}) {
    if (_sessionSubmitted) return true;
    final stored = _cached.submittedDateKey;
    if (stored == null || stored.isEmpty || !_cached.hasSubmittedBetaFeedback) {
      return false;
    }
    return stored == _dateKey(now ?? DateTime.now());
  }

  static Future<void> save(BetaFeedbackIntelligenceState state) async {
    final next = state.copyWith(updatedAt: DateTime.now().toUtc());
    _cached = next;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, next.toJson());
  }

  static Future<void> markProEvidenceBridgeSeen() async {
    await ensureLoaded();
    if (_cached.hasSeenProEvidenceBridge) return;
    await save(_cached.copyWith(hasSeenProEvidenceBridge: true));
  }

  static Future<void> markChatGptDifferentiationSeen() async {
    await ensureLoaded();
    if (_cached.hasSeenChatGptDifferentiation) return;
    await save(_cached.copyWith(hasSeenChatGptDifferentiation: true));
  }

  static Future<void> markProEvidenceSheetOpened() async {
    _proEvidenceSheetOpenedThisSession = true;
    await ensureLoaded();
    await save(
      _cached.copyWith(
        hasOpenedProEvidenceSheet: true,
        hasSeenChatGptDifferentiation: true,
      ),
    );
  }

  static Future<void> saveSubmission({
    required BetaChatGptDifferenceAnswer chatGptDifferenceAnswer,
    required BetaDifferentiatorAnswer differentiatorAnswer,
    required BetaWouldPayAnswer wouldPayAnswer,
    required BetaMainConfusionBucket mainConfusionBucket,
    required BetaStrongestMomentBucket strongestMomentBucket,
    DateTime? now,
  }) async {
    final day = _dateKey(now ?? DateTime.now());
    _sessionSubmitted = true;
    await ensureLoaded();
    await save(
      _cached.copyWith(
        hasSubmittedBetaFeedback: true,
        chatGptDifferenceAnswer: chatGptDifferenceAnswer,
        differentiatorAnswer: differentiatorAnswer,
        wouldPayAnswer: wouldPayAnswer,
        mainConfusionBucket: mainConfusionBucket,
        strongestMomentBucket: strongestMomentBucket,
        submittedDateKey: day,
      ),
    );
  }

  static String _dateKey(DateTime when) {
    final utc = when.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  static void invalidateSessionForTest() {
    _sessionSubmitted = false;
    _proEvidenceSheetOpenedThisSession = false;
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _cached = BetaFeedbackIntelligenceState.empty;
    _loaded = false;
    invalidateSessionForTest();
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }
}
