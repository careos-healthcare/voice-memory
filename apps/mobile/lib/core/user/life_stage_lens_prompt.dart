import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/lenses/career_transition_lens.dart';
import 'package:archiveme_mobile/features/lenses/grief_loss_lens.dart';
import 'package:archiveme_mobile/features/lenses/new_parent_lens.dart';
import 'package:archiveme_mobile/features/lenses/recovery_lens.dart';

/// Mobile mirror of `packages/shared/lib/archive-synthesis/prompt-context-contract.ts`.
abstract final class LifeStageLensPrompt {
  LifeStageLensPrompt._();

  static const header =
      'THEMATIC LENS — CONTEXT ONLY (does not change insight kinds)';

  static String? systemBlockFor(LifeStageLens? lens) {
    final resolved = lens ?? LifeStageLens.defaultLens;
    if (resolved == LifeStageLens.defaultLens) return null;

    final instruction = switch (resolved) {
      LifeStageLens.newParent => NewParentLens.systemPromptInjection,
      LifeStageLens.careerTransition =>
        CareerTransitionLens.systemPromptInjection,
      LifeStageLens.recovery => RecoveryLens.systemPromptInjection,
      LifeStageLens.griefLoss => GriefLossLens.systemPromptInjection,
      LifeStageLens.defaultLens => null,
    };

    if (instruction == null) return null;

    return [
      header,
      instruction,
      'ArchiveInsightKind taxonomy is unchanged — still choose among belief, '
      'beliefChange, theme, contradiction, blindSpot, chapter, weeklyStory, '
      'surprise, and challenge.',
      'This lens adjusts contextual reading of fact_ledger entries only.',
    ].join('\n');
  }
}