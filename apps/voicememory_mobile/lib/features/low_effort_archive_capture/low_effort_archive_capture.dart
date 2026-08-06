import 'low_effort_archive_capture_copy.dart';

/// Beta-only low-effort archive capture decision matrix — interpretation only.
abstract final class LowEffortArchiveCapture {
  LowEffortArchiveCapture._();

  static const minimumTesterCount = 20;
  static const understoodNoDailyRequirementAt30 = 7;
  static const understoodNoDailyRequirementAt20 = 5;
  static const understoodOneSentenceEnoughAt30 = 7;
  static const understoodOneSentenceEnoughAt20 = 5;
  static const understoodNoMindMapMaintenanceAt30 = 7;
  static const understoodNoMindMapMaintenanceAt20 = 5;
  static const understoodSaveWhenRealRepeatAt30 = 7;
  static const understoodSaveWhenRealRepeatAt20 = 5;
  static const thoughtDailyHomeworkHighAt30 = 5;
  static const thoughtDailyHomeworkHighAt20 = 3;
  static const thoughtManualMindMapMaintenanceHighAt30 = 5;
  static const thoughtManualMindMapMaintenanceHighAt20 = 3;
  static const preferredChatGptBecauseLessWorkHighAt30 = 5;
  static const preferredChatGptBecauseLessWorkHighAt20 = 3;
  static const wouldPayYesMaybeAt30 = 3;
  static const wouldPayYesMaybeAt20 = 2;
  static const scaleDenominator = 30;

  static int understoodNoDailyRequirementTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodNoDailyRequirementAt20;
    if (totalTesters == 30) return understoodNoDailyRequirementAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodNoDailyRequirementAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodOneSentenceEnoughTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodOneSentenceEnoughAt20;
    if (totalTesters == 30) return understoodOneSentenceEnoughAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodOneSentenceEnoughAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodNoMindMapMaintenanceTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodNoMindMapMaintenanceAt20;
    if (totalTesters == 30) return understoodNoMindMapMaintenanceAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodNoMindMapMaintenanceAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodSaveWhenRealRepeatTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodSaveWhenRealRepeatAt20;
    if (totalTesters == 30) return understoodSaveWhenRealRepeatAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodSaveWhenRealRepeatAt30,
      denominator: scaleDenominator,
    );
  }

  static int thoughtDailyHomeworkHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return thoughtDailyHomeworkHighAt20;
    if (totalTesters == 30) return thoughtDailyHomeworkHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: thoughtDailyHomeworkHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int thoughtManualMindMapMaintenanceHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return thoughtManualMindMapMaintenanceHighAt20;
    if (totalTesters == 30) return thoughtManualMindMapMaintenanceHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: thoughtManualMindMapMaintenanceHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int preferredChatGptBecauseLessWorkHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return preferredChatGptBecauseLessWorkHighAt20;
    if (totalTesters == 30) return preferredChatGptBecauseLessWorkHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: preferredChatGptBecauseLessWorkHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int wouldPayYesMaybeTargetFor(int totalTesters) {
    if (totalTesters == 20) return wouldPayYesMaybeAt20;
    if (totalTesters == 30) return wouldPayYesMaybeAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: wouldPayYesMaybeAt30,
      denominator: scaleDenominator,
    );
  }

  static LowEffortArchiveCaptureDecision resolve(
    LowEffortArchiveCaptureSummary summary,
  ) {
    if (summary.totalTesters < minimumTesterCount) {
      return LowEffortArchiveCaptureDecision.insufficientData;
    }
    if (_thoughtDailyHomeworkHigh(summary) ||
        !_noDailyRequirementUnderstood(summary)) {
      return LowEffortArchiveCaptureDecision.clarifyNoDailyRequirement;
    }
    if (!_oneSentenceEnoughUnderstood(summary)) {
      return LowEffortArchiveCaptureDecision.clarifyOneSentenceEnough;
    }
    if (_thoughtManualMindMapMaintenanceHigh(summary) ||
        !_noMindMapMaintenanceUnderstood(summary)) {
      return LowEffortArchiveCaptureDecision.clarifyNoMindMapMaintenance;
    }
    if (!_saveWhenRealRepeatUnderstood(summary)) {
      return LowEffortArchiveCaptureDecision.clarifyWhenToUse;
    }
    if (_preferredChatGptBecauseLessWorkHigh(summary)) {
      return LowEffortArchiveCaptureDecision.reduceChatGptLessWorkConcern;
    }
    if (_allLowEffortComprehensionPasses(summary) &&
        !_wouldPayYesMaybePasses(summary)) {
      return LowEffortArchiveCaptureDecision.pricingValidation;
    }
    if (_allLowEffortComprehensionPasses(summary) &&
        _wouldPayYesMaybePasses(summary)) {
      return LowEffortArchiveCaptureDecision.releaseCandidate;
    }
    return LowEffortArchiveCaptureDecision.clarifyNoDailyRequirement;
  }

  static bool _noDailyRequirementUnderstood(
    LowEffortArchiveCaptureSummary summary,
  ) =>
      summary.understoodNoDailyRequirementCount >=
      understoodNoDailyRequirementTargetFor(summary.totalTesters);

  static bool _oneSentenceEnoughUnderstood(
    LowEffortArchiveCaptureSummary summary,
  ) =>
      summary.understoodOneSentenceEnoughCount >=
      understoodOneSentenceEnoughTargetFor(summary.totalTesters);

  static bool _noMindMapMaintenanceUnderstood(
    LowEffortArchiveCaptureSummary summary,
  ) =>
      summary.understoodNoMindMapMaintenanceCount >=
      understoodNoMindMapMaintenanceTargetFor(summary.totalTesters);

  static bool _saveWhenRealRepeatUnderstood(
    LowEffortArchiveCaptureSummary summary,
  ) =>
      summary.understoodSaveWhenRealRepeatCount >=
      understoodSaveWhenRealRepeatTargetFor(summary.totalTesters);

  static bool _thoughtDailyHomeworkHigh(
    LowEffortArchiveCaptureSummary summary,
  ) =>
      summary.thoughtDailyHomeworkCount >=
      thoughtDailyHomeworkHighTargetFor(summary.totalTesters);

  static bool _thoughtManualMindMapMaintenanceHigh(
    LowEffortArchiveCaptureSummary summary,
  ) =>
      summary.thoughtManualMindMapMaintenanceCount >=
      thoughtManualMindMapMaintenanceHighTargetFor(summary.totalTesters);

  static bool _preferredChatGptBecauseLessWorkHigh(
    LowEffortArchiveCaptureSummary summary,
  ) =>
      summary.preferredChatGptBecauseLessWorkCount >=
      preferredChatGptBecauseLessWorkHighTargetFor(summary.totalTesters);

  static int _wouldPayYesMaybeCount(LowEffortArchiveCaptureSummary summary) =>
      summary.wouldPayYesCount + summary.wouldPayMaybeCount;

  static bool _wouldPayYesMaybePasses(LowEffortArchiveCaptureSummary summary) =>
      _wouldPayYesMaybeCount(summary) >=
      wouldPayYesMaybeTargetFor(summary.totalTesters);

  static bool _allLowEffortComprehensionPasses(
    LowEffortArchiveCaptureSummary summary,
  ) =>
      _noDailyRequirementUnderstood(summary) &&
      _oneSentenceEnoughUnderstood(summary) &&
      _noMindMapMaintenanceUnderstood(summary) &&
      _saveWhenRealRepeatUnderstood(summary);

  static LowEffortArchiveCaptureReport report(
    LowEffortArchiveCaptureSummary summary,
    LowEffortArchiveCaptureDecision decision,
  ) => LowEffortArchiveCaptureReport(
    headline: LowEffortArchiveCaptureCopy.headline,
    body: LowEffortArchiveCaptureCopy.body,
    decision: decision,
    guardrail: LowEffortArchiveCaptureCopy.guardrail,
  );

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();
}

enum LowEffortArchiveCaptureDecision {
  insufficientData,
  clarifyNoDailyRequirement,
  clarifyOneSentenceEnough,
  clarifyNoMindMapMaintenance,
  clarifyWhenToUse,
  reduceChatGptLessWorkConcern,
  pricingValidation,
  releaseCandidate,
}

class LowEffortArchiveCaptureSummary {
  const LowEffortArchiveCaptureSummary({
    required this.totalTesters,
    required this.understoodNoDailyRequirementCount,
    required this.understoodOneSentenceEnoughCount,
    required this.understoodNoMindMapMaintenanceCount,
    required this.understoodSaveWhenRealRepeatCount,
    required this.thoughtDailyHomeworkCount,
    required this.thoughtManualMindMapMaintenanceCount,
    required this.preferredChatGptBecauseLessWorkCount,
    required this.wouldPayYesCount,
    required this.wouldPayMaybeCount,
    required this.wouldPayNoCount,
  });

  final int totalTesters;
  final int understoodNoDailyRequirementCount;
  final int understoodOneSentenceEnoughCount;
  final int understoodNoMindMapMaintenanceCount;
  final int understoodSaveWhenRealRepeatCount;
  final int thoughtDailyHomeworkCount;
  final int thoughtManualMindMapMaintenanceCount;
  final int preferredChatGptBecauseLessWorkCount;
  final int wouldPayYesCount;
  final int wouldPayMaybeCount;
  final int wouldPayNoCount;
}

class LowEffortArchiveCaptureReport {
  const LowEffortArchiveCaptureReport({
    required this.headline,
    required this.body,
    required this.decision,
    required this.guardrail,
  });

  final String headline;
  final String body;
  final LowEffortArchiveCaptureDecision decision;
  final String guardrail;
}
