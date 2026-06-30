import '../features/tomorrow_return/return_capture_model.dart';
import '../features/trial/hook_rescue_decision_model.dart';

/// Screenshot / App Store capture — compile with
/// `--dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true`
abstract class ScreenshotMode {
  ScreenshotMode._();

  static const bool enabled = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_MODE',
    defaultValue: false,
  );

  /// Record tab preview: `return_day` (pending watch-for) or `post_save` (full stack).
  static const String recordView = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RECORD_VIEW',
    defaultValue: 'return_day',
  );

  static bool get recordPostSavePreview => enabled && recordView == 'post_save';

  static bool get recordFirstSessionPreview =>
      enabled && recordView == 'first_session';

  static bool get recordCheckInDuePreview =>
      enabled && recordView == 'check_in_due';

  /// Record tab clean-stack preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_RECORD_CLEAN=first_run` (or
  /// `due_check`, `post_save`).
  static const String recordCleanRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RECORD_CLEAN',
    defaultValue: '',
  );

  static const Set<String> _recordCleanModes = {
    'first_run',
    'due_check',
    'post_save',
  };

  static String? get recordClean {
    if (!enabled) return null;
    final value = recordCleanRaw.trim().toLowerCase();
    return _recordCleanModes.contains(value) ? value : null;
  }

  static bool get recordCleanFirstRunPreview =>
      enabled && recordClean == 'first_run';

  static bool get recordCleanDueCheckPreview =>
      enabled && recordClean == 'due_check';

  static bool get recordCleanPostSavePreview =>
      enabled && recordClean == 'post_save';

  static bool get patternsFirstSessionPreview =>
      enabled && recordView == 'first_session';

  /// Journey activation preview: reflection count 0–3 (`VOICE_MEMORY_SCREENSHOT_JOURNEY_STEP`).
  static const String journeyStep = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_JOURNEY_STEP',
    defaultValue: '',
  );

  /// When set (0–3), Record and Patterns use this reflection count for journey UI.
  static int get screenshotJourneyReflectionCount {
    if (!enabled || journeyStep.isEmpty) return -1;
    final n = int.tryParse(journeyStep);
    if (n == null || n < 0 || n > 3) return -1;
    return n;
  }

  static bool get patternsFirstThreePreview =>
      enabled &&
      screenshotJourneyReflectionCount >= 0 &&
      screenshotJourneyReflectionCount < 3;

  /// First-loop activation stage preview:
  /// `start`, `saved`, `choosing`, or `ready`.
  static const String firstLoopStageRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_FIRST_LOOP_STAGE',
    defaultValue: '',
  );

  static const Set<String> _firstLoopStages = {
    'start',
    'saved',
    'choosing',
    'ready',
  };

  /// Validated first-loop stage, or null when not in screenshot mode / unset.
  static String? get firstLoopStage {
    if (!enabled) return null;
    final value = firstLoopStageRaw.trim().toLowerCase();
    return _firstLoopStages.contains(value) ? value : null;
  }

  /// Return-day friction stage preview: `due`, `answered`, or `closed`.
  static const String returnDayStageRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RETURN_DAY_STAGE',
    defaultValue: '',
  );

  static const Set<String> _returnDayStages = {'due', 'answered', 'closed'};

  /// Validated return-day stage, or null when not in screenshot mode / unset.
  static String? get returnDayStage {
    if (!enabled) return null;
    final value = returnDayStageRaw.trim().toLowerCase();
    return _returnDayStages.contains(value) ? value : null;
  }

  /// Return-day quick answer: `same`, `lighter`, `heavier`, or `changed`.
  static const String returnCapture = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RETURN_CAPTURE',
    defaultValue: 'same',
  );

  /// Pre-selected check-in option: `same`, `lighter`, `heavier`, or `changed`.
  static const String checkInOption = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_CHECK_IN_OPTION',
    defaultValue: 'same',
  );

  static String? _checkInOptionId(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'same':
        return 'showed_up_again';
      case 'lighter':
        return 'lighter';
      case 'heavier':
        return 'heavier';
      case 'changed':
        return 'not_today';
      default:
        return null;
    }
  }

  static String? get screenshotCheckInSelectedOptionId =>
      enabled && recordCheckInDuePreview
      ? _checkInOptionId(checkInOption)
      : null;

  /// Hook-fix preview: `sharper`, `very_sharp`, or `better_result`.
  static const String hookFixRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_HOOK_FIX',
    defaultValue: '',
  );

  static const Set<String> _hookFixes = {
    'sharper',
    'very_sharp',
    'better_result',
  };

  /// Validated hook-fix preview, or null when not in screenshot mode / unset.
  static String? get hookFix {
    if (!enabled) return null;
    final value = hookFixRaw.trim().toLowerCase();
    return _hookFixes.contains(value) ? value : null;
  }

  /// Sharper-question intensity to preview, derived from [hookFix].
  static HookRescueIntensity get screenshotSharperIntensity {
    switch (hookFix) {
      case 'sharper':
        return HookRescueIntensity.elevated;
      case 'very_sharp':
        return HookRescueIntensity.aggressive;
      default:
        return HookRescueIntensity.normal;
    }
  }

  /// Whether to preview the better-result interpretation.
  static bool get screenshotBetterResult => hookFix == 'better_result';

  /// Result-to-next-check preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_RESULT_NEXT_CHECK=true`.
  /// Shows a closed loop with the "Next useful check" card.
  static const bool resultNextCheckRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RESULT_NEXT_CHECK',
    defaultValue: false,
  );

  static bool get resultNextCheckPreview => enabled && resultNextCheckRaw;

  /// Useful result rescue preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_USEFUL_RESULT=true`.
  /// Shows a closed loop with the useful takeaway, next check, the "Make this
  /// more useful" path, and the usefulness rating below.
  static const bool usefulResultRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_USEFUL_RESULT',
    defaultValue: false,
  );

  static bool get usefulResultPreview => enabled && usefulResultRaw;

  /// Activation rescue preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_ACTIVATION_RESCUE=first_record`
  /// or `tomorrow_check`, `useful_result`, or `next_check`.
  static const String activationRescueRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ACTIVATION_RESCUE',
    defaultValue: '',
  );

  static const Set<String> _activationRescueStages = {
    'first_record',
    'tomorrow_check',
    'useful_result',
    'next_check',
  };

  static String? get activationRescue {
    if (!enabled) return null;
    final value = activationRescueRaw.trim().toLowerCase();
    return _activationRescueStages.contains(value) ? value : null;
  }

  static bool get activationRescueFirstRecordPreview =>
      activationRescue == 'first_record';

  static bool get activationRescueTomorrowCheckPreview =>
      activationRescue == 'tomorrow_check';

  static bool get activationRescueUsefulResultPreview =>
      activationRescue == 'useful_result';

  static bool get activationRescueNextCheckPreview =>
      activationRescue == 'next_check';

  /// Retention loop preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_RETENTION=check_set`
  /// or `due_today`, `loop_closed`, or `next_ready`.
  static const String retentionRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_RETENTION',
    defaultValue: '',
  );

  static const Set<String> _retentionStages = {
    'check_set',
    'due_today',
    'loop_closed',
    'next_ready',
  };

  static String? get retention {
    if (!enabled) return null;
    final value = retentionRaw.trim().toLowerCase();
    return _retentionStages.contains(value) ? value : null;
  }

  static bool get retentionCheckSetPreview => retention == 'check_set';

  static bool get retentionDueTodayPreview => retention == 'due_today';

  static bool get retentionLoopClosedPreview => retention == 'loop_closed';

  static bool get retentionNextReadyPreview => retention == 'next_ready';

  /// Compelling check preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_COMPELLING_CHECK=true`.
  static const bool compellingCheckRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_COMPELLING_CHECK',
    defaultValue: false,
  );

  static bool get compellingCheckPreview => enabled && compellingCheckRaw;

  /// Real reminder preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_REAL_REMINDER=true`.
  static const bool realReminderRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_REAL_REMINDER',
    defaultValue: false,
  );

  static bool get realReminderPreview => enabled && realReminderRaw;

  /// Current objective preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_OBJECTIVE=due_check`
  /// or `first_moment`, or `next_ready`.
  static const String objectiveRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_OBJECTIVE',
    defaultValue: '',
  );

  static const Set<String> _objectiveStages = {
    'due_check',
    'first_moment',
    'next_ready',
  };

  static String? get objective {
    if (!enabled) return null;
    final value = objectiveRaw.trim().toLowerCase();
    return _objectiveStages.contains(value) ? value : null;
  }

  static bool get objectiveDueCheckPreview => objective == 'due_check';

  static bool get objectiveFirstMomentPreview => objective == 'first_moment';

  static bool get objectiveNextReadyPreview => objective == 'next_ready';

  /// Perspective shift preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_PERSPECTIVE=true`. Shows a closed
  /// loop with the "Another perspective" card, "Show another perspective", and
  /// "Use this check".
  static const bool perspectiveRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_PERSPECTIVE',
    defaultValue: false,
  );

  static bool get perspectivePreview => enabled && perspectiveRaw;

  /// Kinder angle preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_KINDNESS=true`. Shows a closed loop
  /// on a hard, self-blaming reflection with the "A kinder angle" card and
  /// "Use this check".
  static const bool kindnessRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_KINDNESS',
    defaultValue: false,
  );

  static bool get kindnessPreview => enabled && kindnessRaw;

  /// Quick help preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_QUICK_HELP=true`. Shows the record
  /// screen with the "Need help?" pill and opens the Quick help sheet on a
  /// selected response.
  static const bool quickHelpRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_QUICK_HELP',
    defaultValue: false,
  );

  static bool get quickHelpPreview => enabled && quickHelpRaw;

  /// Key Moments preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_KEY_MOMENTS=true`. Shows the Key
  /// moments timeline with three sample days and the detail view.
  static const bool keyMomentsRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_KEY_MOMENTS',
    defaultValue: false,
  );

  static bool get keyMomentsPreview => enabled && keyMomentsRaw;

  /// Pattern map preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_PATTERN_MAP=true`. Shows one
  /// recurring pattern map with a filled-in sample.
  static const bool patternMapRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_PATTERN_MAP',
    defaultValue: false,
  );

  static bool get patternMapPreview => enabled && patternMapRaw;

  /// Feedback learning loop preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_FEEDBACK=true`. Shows a completed
  /// result with the "Was this useful?" feedback chips beneath it.
  static const bool feedbackRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_FEEDBACK',
    defaultValue: false,
  );

  static bool get feedbackPreview => enabled && feedbackRaw;

  /// Archive memory preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_ARCHIVE_MEMORY=true`. Shows the
  /// "What ArchiveMe remembers" summary card on Patterns.
  static const bool archiveMemoryRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_MEMORY',
    defaultValue: false,
  );

  static bool get archiveMemoryPreview => enabled && archiveMemoryRaw;

  /// Archive evolution timeline preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_ARCHIVE_TIMELINE=true`. Shows the
  /// pattern timeline card and full timeline screen.
  static const bool archiveTimelineRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_TIMELINE',
    defaultValue: false,
  );

  static bool get archiveTimelinePreview => enabled && archiveTimelineRaw;

  /// Positioning comprehension rescue — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_POSITIONING_RESCUE=true`.
  /// Shows the first-run archive memory demo on Record and the day-zero
  /// archive preview on Patterns.
  static const bool positioningRescueRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_POSITIONING_RESCUE',
    defaultValue: false,
  );

  static bool get positioningRescuePreview => enabled && positioningRescueRaw;

  /// Ask my Archive preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_ASK_ARCHIVE=true`.
  static const bool askArchiveRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ASK_ARCHIVE',
    defaultValue: false,
  );

  static bool get askArchivePreview => enabled && askArchiveRaw;

  /// Archive clean view preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_ARCHIVE_CLEAN=true`.
  static const bool archiveCleanRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_CLEAN',
    defaultValue: false,
  );

  static bool get archiveCleanPreview => enabled && archiveCleanRaw;

  /// Pattern profile preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_PATTERN_PROFILE=true`.
  static const bool patternProfileRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_PATTERN_PROFILE',
    defaultValue: false,
  );

  static bool get patternProfilePreview => enabled && patternProfileRaw;

  /// Patterns tab clean stack preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_PATTERNS_CLEAN=true`.
  static const bool patternsCleanRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_PATTERNS_CLEAN',
    defaultValue: false,
  );

  static bool get patternsCleanPreview => enabled && patternsCleanRaw;

  /// Archive compression preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_ARCHIVE_COMPRESSION=true`.
  static const bool archiveCompressionRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_COMPRESSION',
    defaultValue: false,
  );

  static bool get archiveCompressionPreview => enabled && archiveCompressionRaw;

  /// Memory quality preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_MEMORY_QUALITY=true`.
  static const bool memoryQualityRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_MEMORY_QUALITY',
    defaultValue: false,
  );

  static bool get memoryQualityPreview => enabled && memoryQualityRaw;

  /// Archive range review preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_ARCHIVE_REVIEW=true`.
  static const bool archiveReviewRaw = bool.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_ARCHIVE_REVIEW',
    defaultValue: false,
  );

  static bool get archiveReviewPreview => enabled && archiveReviewRaw;

  /// Clean confirmed-repeat demo archive — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_DEMO=confirmed_repeat`.
  static const String demoRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_DEMO',
    defaultValue: '',
  );

  static bool get archiveMeDemoPreview =>
      enabled && demoRaw.trim().toLowerCase() == 'confirmed_repeat';

  /// True when a result-focused preview wants the completed check-in card.
  static bool get completedCheckInPreview =>
      resultNextCheckPreview ||
      usefulResultPreview ||
      perspectivePreview ||
      kindnessPreview ||
      feedbackPreview;

  /// Input quality coach preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_INPUT_QUALITY=vague` (shows the
  /// coach card) or `=strong` (skips it).
  static const String inputQualityRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_INPUT_QUALITY',
    defaultValue: '',
  );

  static const Set<String> _inputQualityModes = {'vague', 'strong'};

  /// Validated input-quality preview, or null when not in screenshot mode.
  static String? get inputQuality {
    if (!enabled) return null;
    final value = inputQualityRaw.trim().toLowerCase();
    return _inputQualityModes.contains(value) ? value : null;
  }

  /// True when the vague preview should surface the input quality coach card.
  static bool get inputQualityCoachPreview => inputQuality == 'vague';

  /// Reflection-language preview — compile with
  /// `--dart-define=VOICE_MEMORY_SCREENSHOT_LANGUAGE=es|fr|hi|gu`. Renders
  /// Record guidance, check-in/result labels, and the language chip in the
  /// selected language.
  static const String languageRaw = String.fromEnvironment(
    'VOICE_MEMORY_SCREENSHOT_LANGUAGE',
    defaultValue: '',
  );

  static const Set<String> _languageModes = {'en', 'es', 'fr', 'hi', 'gu'};

  /// Validated language override, or null when not in screenshot mode / unset.
  static String? get language {
    if (!enabled) return null;
    final value = languageRaw.trim().toLowerCase();
    return _languageModes.contains(value) ? value : null;
  }

  /// Language code to render previews in, defaulting to English.
  static String get languageCode => language ?? 'en';

  /// Better-result intensity to preview, derived from [hookFix].
  static HookRescueIntensity get screenshotBetterResultIntensity =>
      hookFix == 'better_result'
      ? HookRescueIntensity.aggressive
      : HookRescueIntensity.normal;

  static ReturnCaptureSelection? get returnCaptureSelection {
    if (!enabled) return null;
    final hint = _returnCaptureHint(returnCapture);
    if (hint == null) return null;
    final answer = _quickAnswerForHint(hint);
    if (answer == null) return null;
    return ReturnCaptureSelection(
      watchForId: 'screenshot-watch-pending',
      selectedQuickAnswerId: answer.id,
      comparisonHint: hint,
      createdAt: DateTime(2026, 5, 26, 9),
    );
  }

  static String? _returnCaptureHint(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'same':
        return ReturnCaptureComparisonHints.same;
      case 'lighter':
        return ReturnCaptureComparisonHints.lighter;
      case 'heavier':
        return ReturnCaptureComparisonHints.heavier;
      case 'changed':
        return ReturnCaptureComparisonHints.changed;
      default:
        return null;
    }
  }

  static ReturnQuickAnswer? _quickAnswerForHint(String hint) {
    for (final answer in kDefaultReturnQuickAnswers) {
      if (answer.comparisonHint == hint) return answer;
    }
    return null;
  }
}
