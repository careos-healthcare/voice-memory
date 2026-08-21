/// Legacy aliases for the Record → Return → Pro loop.
library;

import 'package:archiveme_mobile/features/first_session/two_day_activation_engine.dart';
import 'package:archiveme_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:archiveme_mobile/features/retention/repeat_recording_nudge_state.dart';

export 'record_return_pro_state.dart';

typedef FirstSaveLoopState = RecordReturnProState;
typedef FirstSaveLoopCopy = RecordReturnProCopy;
typedef FirstSaveLoopStage = RecordReturnProStage;
typedef FirstSaveReturnCueMethod = RecordReturnProReturnCueMethod;

/// Legacy gate alias — delegates to [RecordReturnProGates].
abstract class FirstSaveLoopGates {
  FirstSaveLoopGates._();

  static bool showEvidenceCard({
    required int entryCount,
    required bool justSaved,
  }) => RecordReturnProGates.showEvidenceCard(
    entryCount: entryCount,
    justSaved: justSaved,
  );

  static bool showReturnCue({
    required int entryCount,
    required bool justSaved,
    required bool resolved,
  }) => RecordReturnProGates.showReturnCue(
    entryCount: entryCount,
    justSaved: justSaved,
    resolved: resolved,
  );

  static bool showProBridge({
    required int entryCount,
    required bool resolved,
    required bool isPro,
    required bool hasArchiveProof,
  }) => RecordReturnProGates.showProBridge(
    entryCount: entryCount,
    resolved: resolved,
    isPro: isPro,
    hasArchiveProof: hasArchiveProof,
  );

  static bool showArchiveValue({required int entryCount}) =>
      RecordReturnProGates.showArchiveValue(entryCount: entryCount);

  /// Day 2 return reason — one entry, user returned on day 2.
  static bool showDay2Bridge({
    required int entryCount,
    required dynamic stage,
    required bool hasRealChangeInsight,
    bool hiddenThisSession = false,
  }) {
    if (stage is! TwoDayActivationStage) return false;
    return RepeatRecordingNudgeGates.showDay2ReturnReason(
      entryCount: entryCount,
      twoDayPath: TwoDayActivationPath(
        stage: stage,
        title: TwoDayActivationPath.dayTwoTitle,
        lines: const [TwoDayActivationPath.dayTwoLine],
      ),
      hasRealChangeInsight: hasRealChangeInsight,
      hiddenThisSession: hiddenThisSession,
    );
  }
}