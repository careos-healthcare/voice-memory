import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/beta_decision/beta_decision_copy.dart';
import '../../features/beta_decision/beta_decision_engine.dart';
import '../../features/beta_decision/beta_decision_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Beta-only next-build decision card — metadata only, no behaviour changes.
class BetaNextBuildDecisionCard extends StatelessWidget {
  const BetaNextBuildDecisionCard({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
    this.outcomesOverride,
    this.resultOverride,
  });

  final String source;
  final bool compact;
  final List<BetaTesterOutcome>? outcomesOverride;
  final BetaDecisionResult? resultOverride;

  @override
  Widget build(BuildContext context) {
    if (!BetaDecisionEngine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(
        key: Key('beta_next_build_decision_card_hidden'),
      );
    }

    final result = resultOverride ??
        BetaDecisionEngine.build(outcomes: outcomesOverride ?? const []);

    return Container(
      key: const Key('beta_next_build_decision_card'),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            BetaDecisionCopy.cardTitle,
            key: const Key('beta_next_build_decision_card_heading'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            BetaDecisionCopy.cardSubtitle,
            key: const Key('beta_next_build_decision_card_subtitle'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.nextActionCopy,
            key: const Key('beta_next_build_decision_action'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            result.reason,
            key: const Key('beta_next_build_decision_reason'),
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          if (result.failingBranchCounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Failing branches (${result.testerCount} testers)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            for (final entry in result.failingBranchCounts.entries)
              Text(
                '${BetaDecisionCopy.recommendationFor(entry.key)} (${entry.value})',
                key: Key('beta_next_build_branch_${entry.key.name}'),
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'Source: $source · expansion allowed: ${result.expansionAllowed}',
            key: const Key('beta_next_build_decision_meta'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
