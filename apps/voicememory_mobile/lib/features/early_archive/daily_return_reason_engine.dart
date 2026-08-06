import '../../models/journal_entry.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'confirmed_repeat_thought_map_engine.dart';
import 'confirmed_repeat_thought_map_models.dart';
import 'daily_return_reason_copy.dart';
import 'daily_return_reason_model.dart';
import 'positive_pattern_engine.dart';

/// Chooses one grounded reason to record today from archive gaps.
abstract final class DailyReturnReasonEngine {
  DailyReturnReasonEngine._();

  static DailyReturnReasonResult? build({
    required List<JournalEntry> entries,
    RepeatReturnCheckChangeProof? changeProof,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;

    final thoughtMap = ConfirmedRepeatThoughtMapEngine.build(
      entries: entries,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
    );
    final positivePattern = PositivePatternEngine.build(entries: entries);

    if (thoughtMap != null) {
      for (final section in thoughtMap.sections) {
        if (section.isKnown) continue;
        return _forMissingSection(section);
      }
    }

    if (changeProof == null) {
      return const DailyReturnReasonResult(
        title: DailyReturnReasonCopy.title,
        body: DailyReturnReasonCopy.missingChangeBody,
        prompt: DailyReturnReasonCopy.missingChangePrompt,
        guidedRecordPrompt: DailyReturnReasonCopy.missingChangeGuided,
        kind: DailyReturnReasonKind.missingChange,
      );
    }

    if (positivePattern == null || !positivePattern.hasEvidence) {
      return const DailyReturnReasonResult(
        title: DailyReturnReasonCopy.title,
        body: DailyReturnReasonCopy.missingPositiveBody,
        prompt: DailyReturnReasonCopy.missingPositivePrompt,
        guidedRecordPrompt: DailyReturnReasonCopy.missingPositiveGuided,
        kind: DailyReturnReasonKind.missingPositive,
      );
    }

    return const DailyReturnReasonResult(
      title: DailyReturnReasonCopy.title,
      body: DailyReturnReasonCopy.completeBody,
      prompt: DailyReturnReasonCopy.completePrompt,
      guidedRecordPrompt: DailyReturnReasonCopy.completePrompt,
      kind: DailyReturnReasonKind.complete,
    );
  }

  static DailyReturnReasonResult _forMissingSection(ThoughtMapSection section) {
    return switch (section.id) {
      ThoughtMapSectionId.trigger => DailyReturnReasonResult(
        title: DailyReturnReasonCopy.title,
        body: DailyReturnReasonCopy.missingTriggerBody,
        prompt: DailyReturnReasonCopy.missingTriggerPrompt,
        guidedRecordPrompt: section.guidedRecordPrompt,
        kind: DailyReturnReasonKind.missingTrigger,
        targetSection: section.id,
      ),
      ThoughtMapSectionId.thought => DailyReturnReasonResult(
        title: DailyReturnReasonCopy.title,
        body: DailyReturnReasonCopy.missingThoughtBody,
        prompt: DailyReturnReasonCopy.missingThoughtPrompt,
        guidedRecordPrompt: section.guidedRecordPrompt,
        kind: DailyReturnReasonKind.missingThought,
        targetSection: section.id,
      ),
      ThoughtMapSectionId.action => DailyReturnReasonResult(
        title: DailyReturnReasonCopy.title,
        body: DailyReturnReasonCopy.missingActionBody,
        prompt: DailyReturnReasonCopy.missingActionPrompt,
        guidedRecordPrompt: section.guidedRecordPrompt,
        kind: DailyReturnReasonKind.missingAction,
        targetSection: section.id,
      ),
      ThoughtMapSectionId.result => DailyReturnReasonResult(
        title: DailyReturnReasonCopy.title,
        body: DailyReturnReasonCopy.missingResultBody,
        prompt: DailyReturnReasonCopy.missingResultPrompt,
        guidedRecordPrompt: section.guidedRecordPrompt,
        kind: DailyReturnReasonKind.missingResult,
        targetSection: section.id,
      ),
    };
  }
}
