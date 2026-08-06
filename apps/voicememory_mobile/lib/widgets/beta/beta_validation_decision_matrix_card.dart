import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/beta_fix_playbooks/beta_fix_playbook_copy.dart';
import '../../features/beta_fix_playbooks/beta_fix_playbook_engine.dart';
import '../../features/beta_validation_decision_matrix/beta_validation_decision_matrix_copy.dart';
import '../../features/beta_validation_decision_matrix/beta_validation_decision_matrix_engine.dart';
import '../../features/beta_validation_decision_matrix/beta_validation_decision_matrix_model.dart';
import '../../features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Beta/testing-only validation decision matrix — guidance only, no behavior changes.
class BetaValidationDecisionMatrixCard extends StatefulWidget {
  const BetaValidationDecisionMatrixCard({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
    this.resultOverride,
  });

  final String source;
  final bool compact;
  final BetaValidationDecisionMatrixResult? resultOverride;

  @override
  State<BetaValidationDecisionMatrixCard> createState() =>
      _BetaValidationDecisionMatrixCardState();
}

class _BetaValidationDecisionMatrixCardState
    extends State<BetaValidationDecisionMatrixCard> {
  BetaValidationDecisionMatrixResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.resultOverride != null) {
      _result = widget.resultOverride;
      return;
    }
    _loadResult();
  }

  Future<void> _loadResult() async {
    final input = await RevenueReadinessDashboardV2Engine.loadInput();
    if (!mounted) return;
    setState(
      () =>
          _result = BetaValidationDecisionMatrixEngine.fromRevenueInput(input),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!BetaValidationDecisionMatrixEngine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(
        key: Key('beta_validation_decision_matrix_card_hidden'),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink(
        key: Key('beta_validation_decision_matrix_card_loading'),
      );
    }

    return Container(
      key: const Key('beta_validation_decision_matrix_card'),
      padding: EdgeInsets.all(widget.compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            BetaValidationDecisionMatrixCopy.cardTitle,
            key: const Key('beta_validation_decision_matrix_heading'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            BetaValidationDecisionMatrixCopy.cohortTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            result.cohortLabel,
            key: const Key('beta_validation_decision_matrix_tester_count'),
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          Text(
            BetaValidationDecisionMatrixCopy.metricsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final line in result.metricLines)
            Text(
              line,
              key: Key(
                'beta_validation_decision_matrix_metric_${line.split(':').first}',
              ),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          const SizedBox(height: 12),
          Text(
            BetaValidationDecisionMatrixCopy.outcomeTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            result.title,
            key: const Key('beta_validation_decision_matrix_title'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            result.body,
            key: const Key('beta_validation_decision_matrix_body'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            BetaValidationDecisionMatrixCopy.reasonTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            result.reason,
            key: const Key('beta_validation_decision_matrix_reason'),
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          Text(
            BetaValidationDecisionMatrixCopy.onlyFixThisOneNext,
            key: const Key('beta_validation_decision_matrix_only_fix'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (BetaFixPlaybookEngine.hasPlaybook(result.outcome)) ...[
            const SizedBox(height: 6),
            Text(
              BetaFixPlaybookCopy.cardTitle,
              key: const Key('beta_validation_decision_matrix_playbook_hint'),
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('beta_validation_decision_matrix_cta'),
              onPressed: null,
              child: Text(result.cta),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            BetaValidationDecisionMatrixCopy.localCountsNote,
            key: const Key('beta_validation_decision_matrix_note'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
