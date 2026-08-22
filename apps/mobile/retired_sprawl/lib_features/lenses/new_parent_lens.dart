import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';

/// New Parent thematic lens — capacity shifts and pre/post identity comparison.
abstract final class NewParentLens {
  NewParentLens._();

  static const lensId = 'newParent';
  static const String wireValue = lensId;

  static const listenTargets = [
    'fundamental capacity shifts (patience, exhaustion thresholds, tolerance for noise or interruption)',
    'relationship dynamics changing (partner load-sharing, who handles nights, resentment vs gratitude language)',
    'pre-transition vs post-transition identity contradictions (who you said you were vs who entries show now)',
    'sleep fragmentation and recovery language tied to specific dates and roles',
  ];

  static const forbiddenOutput = [
    'parenting advice or prescriptive routines',
    'clinical labels for postpartum or mood states',
    'generic "new parent" platitudes without citing a specific entry',
  ];

  static const systemPromptInjection = '''
NEW PARENT LENS — temporal identity comparison:
1. fundamental capacity shifts (patience, exhaustion thresholds, tolerance for noise or interruption)
2. relationship dynamics changing (partner load-sharing, who handles nights, resentment vs gratitude language)
3. pre-transition vs post-transition identity contradictions (who you said you were vs who entries show now)
4. sleep fragmentation and recovery language tied to specific dates and roles
STRICT FOCUS:
- Compare pre-transition entries with post-transition entries when both exist — prefer contradiction kind.
- Quote dates, baby age markers, partner names, and night/wake timestamps from the ledger.
- Track whether stated capacities (patience, stamina, emotional bandwidth) rise or fall across weeks.
PROHIBITIONS:
- parenting advice or prescriptive routines
- clinical labels for postpartum or mood states
- generic "new parent" platitudes without citing a specific entry''';

  static const comparisonSystemPromptAddendum = '''
NEW PARENT COMPARISON — compare 2-week and 1-month intervals:
- Surface shifts in patience, exhaustion thresholds, and partner/load-sharing dynamics.
- Isolate pre-transition identity language vs post-transition identity language; cite both with dates.
- When the user feels stuck, show baseline movement across intervals using their exact words.
- Never offer parenting advice; evidence citation only.''';

  static const coldStartPromptSeeds = [
    'Who were you on a typical morning before this transition — and who shows up now?',
    'What is the smallest thing that drains your patience faster than it used to?',
    'When did your partner last carry a load you used to handle alone?',
    'What identity word keeps colliding with how exhausted you actually feel?',
  ];

  static const coldStartTitle = 'Capture your shift';
  static const coldStartSubtitle =
      'Name who you were before and who shows up now — dates and roles help ArchiveMe '
      'track capacity changes across weeks.';

  static const comparisonExplorerHeadline =
      'How have your capacities shifted recently?';

  static const comparisonIntervalNudge =
      'Compare the last 2 weeks to the last month — even when you feel stuck, '
      'your patience and exhaustion baseline may be moving.';

  static const beliefChangesEntryTitle = 'See how your baseline is shifting';
  static const beliefChangesEntryBody =
      'Even when parenting feels unchanged day to day, your patience and '
      'exhaustion thresholds may be moving across weeks.';
  static const beliefChangesFortnightCta = 'Compare last 2 weeks';
  static const beliefChangesMonthCta = 'Compare last month';

  static const List<ComparisonTemporalWindow> recommendedComparisonWindows = [
    ComparisonTemporalWindow.fortnight,
    ComparisonTemporalWindow.recent,
  ];

  static ComparisonTemporalWindow get defaultComparisonWindow =>
      ComparisonTemporalWindow.fortnight;

  static bool matches(LifeStageLens? lens) => lens == LifeStageLens.newParent;
}