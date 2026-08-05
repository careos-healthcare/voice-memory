import '../../features/ai_engines/models/ai_accuracy_feedback.dart';
import '../../storage/mobile_prefs_store.dart';

class AiAccuracyFeedbackStore {
  const AiAccuracyFeedbackStore(this.prefs);

  static const prefsKey = 'aiAccuracyFeedbackV1';

  final MobilePrefsStore prefs;

  Future<void> save(AiAccuracyFeedback feedback) => prefs.updateMap(
    prefsKey,
    (current) => {...?current, feedback.conclusionId: feedback.toJson()},
  );

  Future<AiAccuracyFeedback?> load(String conclusionId) async =>
      AiAccuracyFeedback.fromJson(
        (await prefs.readMap(prefsKey))?[conclusionId],
      );

  Future<List<AiAccuracyFeedback>> loadAll() async {
    final raw = await prefs.readMap(prefsKey) ?? const {};
    final result = raw.values
        .map(AiAccuracyFeedback.fromJson)
        .whereType<AiAccuracyFeedback>()
        .toList();
    result.sort(
      (a, b) =>
          (b.feedbackTimestamp ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
              .compareTo(
                a.feedbackTimestamp ??
                    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              ),
    );
    return result;
  }

  Future<AiAccuracyMetrics> metrics() async {
    final feedback = await loadAll();
    return AiAccuracyMetrics(
      correct: feedback
          .where((item) => item.feedbackState == AiFeedbackState.correct)
          .length,
      incorrect: feedback
          .where((item) => item.feedbackState == AiFeedbackState.incorrect)
          .length,
      later: feedback
          .where((item) => item.feedbackState == AiFeedbackState.later)
          .length,
    );
  }

  Future<void> clear() => prefs.writeMap(prefsKey, const <String, dynamic>{});
}
