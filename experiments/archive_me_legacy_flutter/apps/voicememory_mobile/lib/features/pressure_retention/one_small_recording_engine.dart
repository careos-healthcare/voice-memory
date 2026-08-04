import 'daily_return_suggestion_engine.dart';
import 'guided_thread_plan_engine.dart';
import 'one_small_recording_model.dart';
import 'pressure_check_in_record.dart';

/// Picks the single primary prompt for the Record screen — pure and
/// deterministic, no AI calls, no fabricated evidence.
///
/// Selection order:
/// 1. Guided Thread Plan `nextPrompt` when a thread plan is eligible —
///    the prompt continues the user's own tracked thread.
/// 2. The Daily Return Suggestion primary ("Start here today") prompt when
///    suggestion evidence exists but no thread plan does.
/// 3. Otherwise nothing — the Record screen keeps its existing generic
///    prompt section and no card is shown.
class OneSmallRecordingEngine {
  const OneSmallRecordingEngine();

  static const GuidedThreadPlanEngine _planEngine = GuidedThreadPlanEngine();
  static const DailyReturnSuggestionEngine _suggestionEngine =
      DailyReturnSuggestionEngine();

  /// [now] and [entryCount] are injectable for tests; [entryCount] is the
  /// saved journal reflection count and gates archive-context cards.
  OneSmallRecording build(
    List<PressureCheckInRecord> records, {
    DateTime? now,
    int? entryCount,
  }) {
    final plan = _planEngine.build(records, now: now, entryCount: entryCount);
    if (plan.hasPlan && plan.nextPrompt.trim().isNotEmpty) {
      return OneSmallRecording(
        hasRecording: true,
        prompt: plan.nextPrompt,
        sourceTerms: plan.sourceTerms.take(OneSmallRecording.maxTerms).toList(),
        entryIds: plan.entryIds,
      );
    }

    final suggestions = _suggestionEngine.build(records);
    final primary = suggestions.hasSuggestions
        ? suggestions.recommendedSuggestion
        : null;
    if (primary != null && primary.prompt.trim().isNotEmpty) {
      return OneSmallRecording(
        hasRecording: true,
        prompt: primary.prompt,
        sourceTerms: primary.sourceTerms
            .take(OneSmallRecording.maxTerms)
            .toList(),
      );
    }

    return OneSmallRecording.none();
  }
}
