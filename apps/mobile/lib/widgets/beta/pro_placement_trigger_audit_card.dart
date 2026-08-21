import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:archiveme_mobile/features/pro_placement_trigger_audit/pro_placement_trigger_audit_copy.dart';
import 'package:archiveme_mobile/features/pro_placement_trigger_audit/pro_placement_trigger_audit_engine.dart';
import 'package:archiveme_mobile/features/pro_placement_trigger_audit/pro_placement_trigger_audit_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Beta/testing-only Pro placement trigger diagnostics.
class ProPlacementTriggerAuditCard extends StatelessWidget {
  const ProPlacementTriggerAuditCard({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
    this.inputOverride,
  });

  final String source;
  final bool compact;
  final ProPlacementTriggerAuditInput? inputOverride;

  @override
  Widget build(BuildContext context) {
    if (!ProPlacementTriggerAuditEngine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(
        key: Key('pro_placement_trigger_audit_card_hidden'),
      );
    }

    final input =
        inputOverride ??
        ProPlacementTriggerAuditEngine.latestInput ??
        ProPlacementTriggerAuditInput(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          activeRepairMode: BetaRepairLabMode.none,
          entryCount: 0,
          confidenceLevel: ProofConfidenceLevel.watchOnly,
          hasSafeAnchor: false,
          hasMatchQuality: false,
          hasConfirmedRepeat: false,
          hasTimelineProofVisible: false,
          feedbackType: null,
          hasUsefulOrStrongProof: false,
          proPlacementEligible: false,
          proPlacementShown: false,
          proPlacementBlocked: false,
          hasProEngagement: false,
          source: source,
        );

    final result = ProPlacementTriggerAuditEngine.build(input: input);
    if (!result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('pro_placement_trigger_audit_card_no_result'),
      );
    }

    const bodyStyle = TextStyle(fontSize: 12, height: 1.35);

    return Container(
      key: Key('pro_placement_trigger_audit_card_${result.outcome.name}'),
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
            ProPlacementTriggerAuditCopy.cardTitle,
            key: const Key('pro_placement_trigger_audit_heading'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${ProPlacementTriggerAuditCopy.activeRepairLabel}: '
            '${result.activeRepairModeLabel}',
            key: const Key('pro_placement_trigger_audit_active_repair'),
            style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '${ProPlacementTriggerAuditCopy.outcomeLabel}: ${result.title}',
            key: const Key('pro_placement_trigger_audit_outcome'),
            style: bodyStyle,
          ),
          const SizedBox(height: 4),
          Text(
            result.body,
            key: const Key('pro_placement_trigger_audit_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: 6),
          Text(
            '${ProPlacementTriggerAuditCopy.blockReasonLabel}: ${result.blockReason}',
            key: const Key('pro_placement_trigger_audit_block_reason'),
            style: bodyStyle.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 8),
          Text(
            result.warning,
            key: const Key('pro_placement_trigger_audit_warning'),
            style: bodyStyle.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ProPlacementTriggerAuditCopy.localNote,
            key: const Key('pro_placement_trigger_audit_note'),
            style: bodyStyle.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}