import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/beta/tester_mission_copy.dart';
import 'package:archiveme_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:archiveme_mobile/features/early_archive/first_week_loop_copy.dart';
import 'package:archiveme_mobile/features/early_archive/post_save_return_check_answer_copy.dart';
import 'package:archiveme_mobile/features/early_archive/post_save_return_handoff_copy.dart';
import 'package:archiveme_mobile/features/first_use_wording/first_use_wording_copy.dart';
import 'package:archiveme_mobile/features/moment_quality/moment_quality_feedback_copy.dart';
import 'package:archiveme_mobile/record/record_screen_framing_copy.dart';

/// Guards early capture surfaces from chatbot / journaling-friction language.
abstract final class LowEffortCaptureCopyGuard {
  LowEffortCaptureCopyGuard._();

  static const bannedFrictionPhrases = [
    'write a full reflection',
    'explain the situation',
    'ask archiveme',
    'ask ai',
    'chat with ai',
    'journal every day',
    'complete your entry',
    'daily journaling',
    'perfect entry',
    'full context',
    'reflection exercise',
  ];

  static Iterable<String> violationsIn(String text) sync* {
    final lower = text.toLowerCase();
    for (final phrase in bannedFrictionPhrases) {
      if (lower.contains(phrase)) yield phrase;
    }
    if (lower.contains('prompt') && !lower.contains('no prompt needed')) {
      yield 'prompt';
    }
  }

  static bool passes(String text) => violationsIn(text).isEmpty;

  static List<String> mainCaptureCopyBlocks() => [
    RecordFirstUsePromptCopy.title,
    RecordFirstUsePromptCopy.body,
    RecordFirstUsePromptCopy.footer,
    FirstUseWordingCopy.title,
    FirstUseWordingCopy.body,
    FirstUseWordingCopy.useOpeningCta,
    MomentQualityFeedbackCopy.specificUsableTitle,
    MomentQualityFeedbackCopy.specificUsableBody,
    MomentQualityFeedbackCopy.savedTitle,
    MomentQualityFeedbackCopy.tooShortBody,
    MomentQualityFeedbackCopy.quietDayTitle,
    MomentQualityFeedbackCopy.quietDayBody,
    MomentQualityFeedbackCopy.genericTestBody,
    MomentQualityFeedbackCopy.pendingTranscriptBody,
    RecordScreenFramingCopy.emptyArchiveBody,
    VisibleArchiveProofCopy.firstUseCaptureCta,
    TesterMissionCopy.entry0Body,
    TesterMissionCopy.entry0Footer,
    TesterMissionCopy.entry1Body,
    TesterMissionCopy.entry1Footer,
    EarlyRepeatProgressCopy.oneMomentTitle,
    EarlyRepeatProgressCopy.oneMomentBody,
    EarlyRepeatProgressCopy.oneMomentCueFooter,
    EarlyRepeatProgressCopy.twoRelatedCueFooter,
    PostSaveReturnHandoffCopy.afterFirstSaveTitle,
    PostSaveReturnHandoffCopy.afterFirstSaveBodyFallback,
    PostSaveReturnHandoffCopy.afterFirstSaveFooter,
    FirstWeekLoopCopy.title,
    FirstWeekLoopCopy.bodyFallback,
    FirstWeekLoopCopy.footer,
    FirstWeekLoopCopy.bodyWithPhrase('said yes again'),
    PostSaveReturnCheckAnswerCopy.title,
    PostSaveReturnCheckAnswerCopy.bodyFallback,
    PostSaveReturnCheckAnswerCopy.footer,
  ];
}