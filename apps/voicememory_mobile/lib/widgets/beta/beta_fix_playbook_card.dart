import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/beta_fix_playbooks/beta_fix_playbook_copy.dart';
import '../../features/beta_fix_playbooks/beta_fix_playbook_engine.dart';
import '../../features/beta_fix_playbooks/beta_fix_playbook_model.dart';
import '../../features/beta_validation_decision_matrix/beta_validation_decision_matrix_engine.dart';
import '../../features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Beta/testing-only inactive fix playbook — guidance only, no behavior changes.
class BetaFixPlaybookCard extends StatefulWidget {
  const BetaFixPlaybookCard({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
    this.resultOverride,
  });

  final String source;
  final bool compact;
  final BetaFixPlaybookResult? resultOverride;

  @override
  State<BetaFixPlaybookCard> createState() => _BetaFixPlaybookCardState();
}

class _BetaFixPlaybookCardState extends State<BetaFixPlaybookCard> {
  BetaFixPlaybookResult? _result;

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
    final validation = BetaValidationDecisionMatrixEngine.fromRevenueInput(
      input,
    );
    setState(
      () => _result = BetaFixPlaybookEngine.fromValidationResult(validation),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!BetaFixPlaybookEngine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(key: Key('beta_fix_playbook_card_hidden'));
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink(key: Key('beta_fix_playbook_card_loading'));
    }
    if (!result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('beta_fix_playbook_card_no_playbook'),
      );
    }

    return Container(
      key: Key('beta_fix_playbook_card_${result.outcome.name}'),
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
            BetaFixPlaybookCopy.cardTitle,
            key: const Key('beta_fix_playbook_card_heading'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            result.title,
            key: const Key('beta_fix_playbook_title'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            BetaFixPlaybookCopy.diagnosisTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            result.diagnosis,
            key: const Key('beta_fix_playbook_diagnosis'),
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            BetaFixPlaybookCopy.fixPlanTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          for (final step in result.fixPlan)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $step',
                key: Key(
                  'beta_fix_playbook_fix_${result.fixPlan.indexOf(step)}',
                ),
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            BetaFixPlaybookCopy.doNotDoTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          for (final step in result.doNotDo)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $step',
                key: Key(
                  'beta_fix_playbook_dont_${result.doNotDo.indexOf(step)}',
                ),
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            BetaFixPlaybookCopy.guidanceOnlyNote,
            key: const Key('beta_fix_playbook_guidance_only'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
