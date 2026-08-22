import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';

/// Grief / Loss thematic lens — cyclical patterns without progress pressure.
abstract final class GriefLossLens {
  GriefLossLens._();

  static const lensId = 'griefLoss';
  static const String wireValue = lensId;

  static const listenTargets = [
    'cyclical patterns (time of day, day of week, anniversaries, seasons)',
    'non-linear emotional movement (okay in mornings, harder Sunday evenings — cite both)',
    'avoidance and sudden reversals in meaning-making language',
    'relationship and routine changes after the loss without labeling stages',
  ];

  static const forbiddenOutput = [
    'progress, healing, closure, or "moving forward" framing',
    'stages-of-grief or therapeutic directives',
    'reassurance not grounded in cited ledger entries',
  ];

  static const systemPromptInjection = '''
GRIEF / LOSS LENS — cyclical mirror only:
1. cyclical patterns (time of day, day of week, anniversaries, seasons)
2. non-linear emotional movement (okay in mornings, harder Sunday evenings — cite both)
3. avoidance and sudden reversals in meaning-making language
4. relationship and routine changes after the loss without labeling stages
STRICT PROHIBITIONS:
- progress, healing, closure, or "moving forward" framing
- stages-of-grief or therapeutic directives
- reassurance not grounded in cited ledger entries
Describe movement across dates without implying linear improvement.
Quote the user's phrasing for when things feel lighter vs heavier.
If evidence is thin, say so plainly — never fill gaps with comfort language.''';

  static const comparisonSystemPromptAddendum = '''
GRIEF/LOSS COMPARISON — compare 2-week and 1-month intervals:
- Identify cyclical patterns (e.g., okay in mornings, harder Sunday evenings) using exact quotes and dates.
- Show non-linear movement — do not imply progress, healing, closure, or stages of grief.
- When the user feels stuck, prove baseline shifts across intervals with cited evidence only.
- Forbidden comparison framing: "moving forward", "healing journey", "getting better", "making progress".''';

  static const coldStartPromptSeeds = [
    'What time of day or day of week feels hardest lately — and when feels lighter?',
    'What routine changed after the loss that still catches you off guard?',
    'What phrase do you use when you feel okay — and what replaces it later?',
    'What anniversary, place, or object keeps returning in your entries?',
  ];

  static const coldStartTitle = 'Capture what cycles';
  static const coldStartSubtitle =
      'Name when things feel lighter vs heavier — no progress story, just your words '
      'and dates for the fact ledger.';

  static const comparisonExplorerHeadline =
      'What cycles show up across your archive?';

  static const comparisonIntervalNudge =
      'Compare the last 2 weeks to the last month — grief moves in cycles, not straight lines. '
      'Look for time-of-day or day-of-week patterns even when a week feels unchanged.';

  static const beliefChangesEntryTitle = 'Track cycles, not progress';
  static const beliefChangesEntryBody =
      'Grief moves in cycles — mornings vs Sunday evenings, quiet weeks vs hard ones. '
      'Compare intervals to see movement without a healing timeline.';
  static const beliefChangesFortnightCta = 'Compare last 2 weeks';
  static const beliefChangesMonthCta = 'Compare last month';

  static const List<ComparisonTemporalWindow> recommendedComparisonWindows = [
    ComparisonTemporalWindow.fortnight,
    ComparisonTemporalWindow.recent,
  ];

  static ComparisonTemporalWindow get defaultComparisonWindow =>
      ComparisonTemporalWindow.fortnight;

  static bool matches(LifeStageLens? lens) => lens == LifeStageLens.griefLoss;
}