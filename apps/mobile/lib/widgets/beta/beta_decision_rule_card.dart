import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_decision_rules/beta_decision_rule_copy.dart';
import 'package:archiveme_mobile/features/beta_decision_rules/beta_decision_rule_engine.dart';
import 'package:archiveme_mobile/features/beta_decision_rules/beta_decision_rule_model.dart';
import 'package:archiveme_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Beta-only decision rule card — metadata counts only, no behavior changes.
class BetaDecisionRuleCard extends StatefulWidget {
  const BetaDecisionRuleCard({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
    this.resultOverride,
  });

  final String source;
  final bool compact;
  final BetaDecisionRuleResult? resultOverride;

  @override
  State<BetaDecisionRuleCard> createState() => _BetaDecisionRuleCardState();
}

class _BetaDecisionRuleCardState extends State<BetaDecisionRuleCard> {
  BetaDecisionRuleResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.resultOverride != null) {
      _result = widget.resultOverride;
      return;
    }
    unawaited(_loadResult());
  }

  Future<void> _loadResult() async {
    final input = await RevenueReadinessDashboardV2Engine.loadInput();
    if (!mounted) return;
    setState(() => _result = BetaDecisionRuleEngine.fromRevenueInput(input));
  }

  @override
  Widget build(BuildContext context) {
    if (!BetaDecisionRuleEngine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(key: Key('beta_decision_rule_card_hidden'));
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink(key: Key('beta_decision_rule_card_loading'));
    }

    return Container(
      key: const Key('beta_decision_rule_card'),
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
            BetaDecisionRuleCopy.cardTitle,
            key: const Key('beta_decision_rule_card_heading'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            BetaDecisionRuleCopy.inputsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final line in result.inputLines)
            Text(
              line,
              key: Key('beta_decision_rule_input_${line.split(':').first}'),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          const SizedBox(height: 12),
          Text(
            result.title,
            key: const Key('beta_decision_rule_title'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            result.body,
            key: const Key('beta_decision_rule_body'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            BetaDecisionRuleCopy.reasonTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            result.reason,
            key: const Key('beta_decision_rule_reason'),
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('beta_decision_rule_cta'),
              onPressed: null,
              child: Text(result.cta),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            BetaDecisionRuleCopy.localCountsNote,
            key: Key('beta_decision_rule_note'),
            style: TextStyle(
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