import '../../models/journal_entry.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'pattern_detail_engine.dart';

/// Inputs needed to rebuild pattern detail after a moment delete.
class PatternDetailBuildInput {
  const PatternDetailBuildInput({
    required this.entries,
    this.confirmedRepeat,
    this.changeProof,
    this.returnChecks = const [],
    this.triggerCapturedMilestone = false,
    this.helpfulActionCapturedMilestone = false,
    required this.viewingConfirmedRepeatOrTimeline,
  });

  final List<JournalEntry> entries;
  final EarlyFirstSignalModel? confirmedRepeat;
  final RepeatReturnCheckChangeProof? changeProof;
  final List<RepeatReturnCheckRecord> returnChecks;
  final bool triggerCapturedMilestone;
  final bool helpfulActionCapturedMilestone;
  final bool viewingConfirmedRepeatOrTimeline;

  PatternDetailResult? buildDetail() => PatternDetailEngine.build(
    entries: entries,
    confirmedRepeat: confirmedRepeat,
    changeProof: changeProof,
    returnChecks: returnChecks,
    triggerCapturedMilestone: triggerCapturedMilestone,
    helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
  );
}

/// One saved moment row in pattern detail — no internal ids in UI.
class PatternDetailMoment {
  const PatternDetailMoment({
    required this.entryId,
    required this.dateTimeLabel,
    required this.previewText,
    required this.statusChipLabel,
    required this.statusKey,
    this.isImportant = false,
  });

  final String entryId;
  final String dateTimeLabel;
  final String previewText;
  final String statusChipLabel;
  final String statusKey;
  final bool isImportant;
}

/// Content for the pattern detail bottom sheet.
class PatternDetailResult {
  const PatternDetailResult({
    required this.patternLabel,
    required this.patternKey,
    required this.evidencePhrases,
    required this.whatChangedBody,
    required this.whatChangedSupported,
    required this.whatHelpedBody,
    required this.whatHelpedSupported,
    required this.whatToWatchNextBody,
    required this.savedMoments,
  });

  final String patternLabel;
  final String patternKey;
  final List<String> evidencePhrases;
  final String whatChangedBody;
  final bool whatChangedSupported;
  final String whatHelpedBody;
  final bool whatHelpedSupported;
  final String whatToWatchNextBody;
  final List<PatternDetailMoment> savedMoments;

  bool get hasSavedMoments => savedMoments.isNotEmpty;

  bool get showWhyThisMatters => savedMoments.length >= 3;
}
