import 'package:archiveme_mobile/features/three_moment_completion/three_moment_completion_copy.dart';
import 'package:archiveme_mobile/features/three_moment_completion/three_moment_completion_model.dart';
import 'package:archiveme_mobile/features/three_moment_completion/three_moment_completion_store.dart';

/// Unified early guidance for the first three saves — visibility only.
abstract final class ThreeMomentCompletionEngine {
  ThreeMomentCompletionEngine._();

  static const maxEntryCount = 2;

  static ThreeMomentCompletionResult build({
    required int entryCount,
    required String source,
  }) {
    final stage = _stageFor(entryCount);
    if (stage == null) {
      return ThreeMomentCompletionResult(
        shouldShow: false,
        stage: ThreeMomentCompletionStage.start,
        title: '',
        body: '',
        noPressureLine: ThreeMomentCompletionCopy.noPressureLine,
        primaryCta: '',
        secondaryCta: ThreeMomentCompletionCopy.secondaryCta,
        primaryActionType: ThreeMomentCompletionActionType.saveOneSentence,
        entryCount: entryCount,
        source: source,
      );
    }

    return switch (stage) {
      ThreeMomentCompletionStage.start => ThreeMomentCompletionResult(
        shouldShow: true,
        stage: stage,
        title: ThreeMomentCompletionCopy.startTitle,
        body: ThreeMomentCompletionCopy.startBody,
        noPressureLine: ThreeMomentCompletionCopy.noPressureLine,
        primaryCta: ThreeMomentCompletionCopy.startPrimaryCta,
        secondaryCta: ThreeMomentCompletionCopy.secondaryCta,
        primaryActionType: ThreeMomentCompletionActionType.saveOneSentence,
        entryCount: entryCount,
        source: source,
      ),
      ThreeMomentCompletionStage.second => ThreeMomentCompletionResult(
        shouldShow: true,
        stage: stage,
        title: ThreeMomentCompletionCopy.secondTitle,
        body: ThreeMomentCompletionCopy.secondBody,
        noPressureLine: ThreeMomentCompletionCopy.noPressureLine,
        primaryCta: ThreeMomentCompletionCopy.secondPrimaryCta,
        secondaryCta: ThreeMomentCompletionCopy.secondaryCta,
        primaryActionType: ThreeMomentCompletionActionType.noticedSomething,
        entryCount: entryCount,
        source: source,
      ),
      ThreeMomentCompletionStage.third => ThreeMomentCompletionResult(
        shouldShow: true,
        stage: stage,
        title: ThreeMomentCompletionCopy.thirdTitle,
        body: ThreeMomentCompletionCopy.thirdBody,
        noPressureLine: ThreeMomentCompletionCopy.noPressureLine,
        primaryCta: ThreeMomentCompletionCopy.thirdPrimaryCta,
        secondaryCta: ThreeMomentCompletionCopy.secondaryCta,
        primaryActionType: ThreeMomentCompletionActionType.saveOneMoreMoment,
        entryCount: entryCount,
        source: source,
      ),
    };
  }

  static bool shouldShow({
    required ThreeMomentCompletionResult? result,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool isPermissionBlocked,
    required int entryCount,
    required bool dismissedForToday,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (entryCount > maxEntryCount) return false;
    if (dismissedForToday) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (entryCount == 0 && isPermissionBlocked) return false;
    return true;
  }

  static bool suppressesLegacyEarlyGuidance({
    required bool threeMomentCompletionVisible,
  }) => threeMomentCompletionVisible;

  static ThreeMomentCompletionStage? _stageFor(int entryCount) =>
      switch (entryCount) {
        0 => ThreeMomentCompletionStage.start,
        1 => ThreeMomentCompletionStage.second,
        2 => ThreeMomentCompletionStage.third,
        _ => null,
      };

  static bool isDismissedToday() => ThreeMomentCompletionStore.isDismissedToday;
}