import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_model.dart';
import 'package:archiveme_mobile/features/referral/invite_funnel_metrics.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/memory/memory_card_visibility_controls.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/value_accuracy_feedback_row.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compact thread continuity card: what returned, how often, and the exact
/// recordings behind it. Renders nothing without real repeated evidence.
class ThreadReturnEvidenceCard extends StatelessWidget {
  const ThreadReturnEvidenceCard({required this.evidence, super.key});

  final ThreadReturnEvidence evidence;

  @override
  Widget build(BuildContext context) {
    if (!evidence.hasEvidence) return const SizedBox.shrink();
    // "Not related" suppresses this suggested connection for the session.
    if (MemoryControlStore.isSuppressed(MemoryCardType.threadReturn) ||
        WrongThreadFeedback.isSessionSuppressed(MemoryCardType.threadReturn)) {
      return const SizedBox.shrink();
    }

    final governance = MemoryCardVisibilityGate.evaluateGovernance(
      cardType: MemoryCardType.threadReturn,
      memoryUsed: true,
      entryCount: evidence.occurrenceCount,
    );
    final reliability = governance?.reliability;
    final blockClaim = MemoryCardVisibilityGate.blocksStrongClaim(
      cardType: MemoryCardType.threadReturn,
      memoryUsed: true,
      entryCount: evidence.occurrenceCount,
      governance: governance,
      reliability: reliability,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.threadReturnEvidenceSeen,
      hasConnectedThread: true,
      entryCount: evidence.occurrenceCount,
      oncePerSession: true,
    );
    // Invited funnel mirror — additive, attribution-gated.
    InviteFunnelMetrics.valueMomentSeen('thread_return');

    return Container(
      key: const Key('thread_return_evidence_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F4FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_outlined,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  evidence.headline,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          if (blockClaim)
            MemoryCardVisibilityControls(
              cardType: MemoryCardType.threadReturn,
              memoryUsed: true,
              entryCount: evidence.occurrenceCount,
              reliability: reliability,
              governance: governance,
              showCrossThreadGate: true,
            ),
          if (!blockClaim) ...[
            if (evidence.namedLine.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                evidence.namedLine,
                key: const Key('thread_return_named_line'),
                style: ArchiveMobileTypography.responsiveHelper(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              evidence.summaryLine,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _statusChip(context),
                _pill(context, evidence.confidenceLabel),
                for (final term in evidence.sourceTerms)
                  _termChip(context, term),
              ],
            ),
            if (evidence.evidenceSnippets.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                ThreadReturnEvidence.evidenceHeading,
                style: ArchiveMobileTypography.responsiveHelper(context)
                    .copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              for (final snippet in evidence.evidenceSnippets)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '\u201C$snippet\u201D',
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textPrimary),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              ThreadReturnEvidence.basedOnLine,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
            if (evidence.followUpCtaLabel.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  key: const Key('thread_return_follow_up_cta'),
                  onPressed: () => _openRecordWithPrompt(context),
                  child: Text(
                    evidence.followUpCtaLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
          if (!blockClaim)
            MemoryCardVisibilityControls(
              cardType: MemoryCardType.threadReturn,
              memoryUsed: true,
              entryCount: evidence.occurrenceCount,
              reliability: reliability,
              governance: governance,
            ),
          ValueAccuracyFeedbackRow(
            cardType: 'thread_return_evidence',
            entryCount: evidence.occurrenceCount,
            hasConnectedThread: true,
          ),
        ],
      ),
    );
  }

  /// Hands the follow-up prompt to the Record screen using the existing
  /// `?prompt=` deep-link pattern — the prompt arrives pre-selected and the
  /// user starts recording when ready.
  void _openRecordWithPrompt(BuildContext context) {
    final prompt = evidence.followUpPrompt.trim();
    if (prompt.isEmpty) {
      context.go('/record');
      return;
    }
    context.go('/record?prompt=${Uri.encodeComponent(prompt)}');
  }

  Widget _statusChip(BuildContext context) {
    return Container(
      key: const Key('thread_return_status_chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        evidence.statusLabel,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _pill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _termChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      ),
    );
  }
}