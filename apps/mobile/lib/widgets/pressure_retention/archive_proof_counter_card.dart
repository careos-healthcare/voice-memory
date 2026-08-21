import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pressure_retention/archive_proof_counter_model.dart';
import 'package:archiveme_mobile/features/referral/invite_funnel_metrics.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/value_accuracy_feedback_row.dart';
import 'package:flutter/material.dart';

/// Compact proof lines that the archive is accumulating evidence: connected
/// recordings, thread returns, and readiness to compare tomorrow. Renders
/// nothing without meaningful evidence. No buttons, no Pro gate, no streaks.
class ArchiveProofCounterCard extends StatelessWidget {
  const ArchiveProofCounterCard({required this.counter, super.key});

  final ArchiveProofCounter counter;

  @override
  Widget build(BuildContext context) {
    if (!counter.hasProof) return const SizedBox.shrink();

    final lines = <String>[
      if (counter.connectedLine.isNotEmpty) counter.connectedLine,
      if (counter.threadReturnLine.isNotEmpty) counter.threadReturnLine,
      if (counter.readinessLine.isNotEmpty) counter.readinessLine,
      if (counter.onePieceLine.isNotEmpty) counter.onePieceLine,
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveProofCounterSeen,
      hasConnectedThread: counter.connectedCount >= 2,
      oncePerSession: true,
    );
    // Invited funnel mirror — additive, attribution-gated.
    InviteFunnelMetrics.valueMomentSeen('proof_counter');

    return Container(
      key: const Key('archive_proof_counter_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4F7F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    lines[i],
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ],
          // Feedback only when the counters show a genuinely connected
          // thread — the minimal one-piece state is too thin to rate.
          if (counter.connectedCount >= 2)
            ValueAccuracyFeedbackRow(
              cardType: 'archive_proof_counter',
              entryCount: counter.connectedCount,
              hasConnectedThread: true,
            ),
        ],
      ),
    );
  }
}