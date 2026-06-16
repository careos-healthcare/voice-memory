import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/aha/aha_moment_candidate.dart';
import '../../features/trust/aha_proof_share_eligibility.dart';
import '../../features/memory/memory_connection_rules.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/not_important_feedback.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Useful / Not quite feedback for the first-aha card.
class AhaMomentFeedbackRow extends StatefulWidget {
  const AhaMomentFeedbackRow({
    super.key,
    required this.candidate,
    required this.onFeedback,
    this.source = 'record',
  });

  final AhaMomentCandidate candidate;
  final VoidCallback onFeedback;
  final String source;

  @override
  State<AhaMomentFeedbackRow> createState() => _AhaMomentFeedbackRowState();
}

class _AhaMomentFeedbackRowState extends State<AhaMomentFeedbackRow> {
  bool? _answered;

  void _submit(bool useful) {
    if (_answered != null) return;
    setState(() => _answered = useful);
    if (useful) {
      MemoryConnectionRules.keepConnected(
        AhaMomentCandidate.underlyingCardType,
      );
      AhaProofShareEligibility.markEligibleFromAhaUseful();
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.ahaMomentUseful,
        cardType: AhaMomentCardType.id,
        entryCount: widget.candidate.entryCount,
        memoryScope: widget.candidate.memoryScope,
        priorityBand: widget.candidate.priorityBand,
        authorityState: widget.candidate.authorityStateId,
        source: widget.source,
      );
    } else {
      NotImportantFeedback.markNotImportant(
        AhaMomentCandidate.underlyingCardType,
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.ahaMomentNotQuite,
        cardType: AhaMomentCardType.id,
        entryCount: widget.candidate.entryCount,
        memoryScope: widget.candidate.memoryScope,
        priorityBand: widget.candidate.priorityBand,
        authorityState: widget.candidate.authorityStateId,
        source: widget.source,
      );
    }
    widget.onFeedback();
  }

  @override
  Widget build(BuildContext context) {
    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary);

    if (_answered != null) {
      return Padding(
        key: const Key('aha_moment_feedback_thanks'),
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          _answered!
              ? AhaMomentCopy.usefulThanks
              : AhaMomentCopy.notQuiteThanks,
          style: helperStyle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text('Was this helpful?', style: helperStyle)),
          _chip(
            context,
            key: const Key('aha_moment_useful'),
            label: AhaMomentCopy.usefulLabel,
            onTap: () => _submit(true),
          ),
          const SizedBox(width: AppSpacing.xs),
          _chip(
            context,
            key: const Key('aha_moment_not_quite'),
            label: AhaMomentCopy.notQuiteLabel,
            onTap: () => _submit(false),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
