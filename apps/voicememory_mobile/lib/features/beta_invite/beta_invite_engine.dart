import 'beta_invite_copy.dart';
import 'beta_invite_models.dart';

/// Deterministic beta invite summaries — counts only.
class BetaInviteEngine {
  const BetaInviteEngine();

  BetaInviteOutcomesSummary outcomesSummary(BetaInviteCopyStats stats) {
    final lastVariant = stats.lastVariantId == null
        ? BetaInviteCopy.betaOutcomesNoneLabel
        : BetaInviteCopy.variantTitle(stats.lastVariantId!);
    return BetaInviteOutcomesSummary(
      totalCopiedCount: stats.totalCopiedCount,
      lastVariantLabel: lastVariant,
      testerTaskCopied: stats.testerTaskCopied,
    );
  }
}
