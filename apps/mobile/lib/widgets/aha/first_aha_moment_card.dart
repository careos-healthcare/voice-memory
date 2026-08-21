import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/aha/aha_moment_candidate.dart';
import 'package:archiveme_mobile/features/aha/aha_moment_store.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_decision.dart';
import 'package:archiveme_mobile/features/memory/not_important_feedback.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/aha/aha_moment_feedback_row.dart';
import 'package:archiveme_mobile/widgets/memory/memory_evidence_inspect_sheet.dart';
import 'package:flutter/material.dart';

/// First honest archive "aha" — shown once when enough evidence exists.
class FirstAhaMomentCard extends StatefulWidget {
  const FirstAhaMomentCard({
    required this.candidate, required this.onChanged, super.key,
    this.source = 'record',
  });

  final AhaMomentCandidate candidate;
  final VoidCallback onChanged;
  final String source;

  @override
  State<FirstAhaMomentCard> createState() => _FirstAhaMomentCardState();
}

class _FirstAhaMomentCardState extends State<FirstAhaMomentCard> {
  var _trackedSeen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackSeenOnce());
  }

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.ahaMomentSeen,
      cardType: AhaMomentCardType.id,
      entryCount: widget.candidate.entryCount,
      memoryScope: widget.candidate.memoryScope,
      priorityBand: widget.candidate.priorityBand,
      authorityState: widget.candidate.authorityStateId,
      source: widget.source,
      oncePerSession: true,
    );
    AhaMomentSession.markShown();
  }

  Future<void> _complete({required String analyticsEvent}) async {
    await AhaMomentStore.markFirstAhaCompleted();
    widget.onChanged();
  }

  Future<void> _dismiss() async {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.ahaMomentDismissed,
      cardType: AhaMomentCardType.id,
      entryCount: widget.candidate.entryCount,
      memoryScope: widget.candidate.memoryScope,
      priorityBand: widget.candidate.priorityBand,
      authorityState: widget.candidate.authorityStateId,
      source: widget.source,
    );
    AhaMomentSession.dismiss();
    await _complete(
      analyticsEvent: ActivationFunnelAnalytics.ahaMomentDismissed,
    );
  }

  Future<void> _showEvidence() async {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.ahaMomentShowEvidenceTapped,
      cardType: AhaMomentCardType.id,
      entryCount: widget.candidate.entryCount,
      memoryScope: widget.candidate.memoryScope,
      priorityBand: widget.candidate.priorityBand,
      authorityState: widget.candidate.authorityStateId,
      source: widget.source,
    );
    await MemoryEvidenceInspectSheet.show(
      context,
      AhaMomentCandidate.underlyingCardType,
    );
  }

  Future<void> _notRelated() async {
    MemoryControlStore.markNotRelated(AhaMomentCandidate.underlyingCardType);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryMarkedNotRelated,
      cardType: AhaMomentCandidate.underlyingCardType.id,
    );
    AhaMomentSession.dismiss();
    await _complete(
      analyticsEvent: ActivationFunnelAnalytics.memoryMarkedNotRelated,
    );
  }

  Future<void> _notImportant() async {
    NotImportantFeedback.markNotImportant(
      AhaMomentCandidate.underlyingCardType,
    );
    AhaMomentSession.dismiss();
    await _complete(
      analyticsEvent: ActivationFunnelAnalytics.memoryNotImportantSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('first_aha_moment_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F4FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  widget.candidate.title,
                  key: const Key('aha_moment_title'),
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
              IconButton(
                key: const Key('aha_moment_dismiss'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Dismiss',
                onPressed: _dismiss,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.candidate.body,
            key: const Key('aha_moment_body'),
            style: ArchiveMobileTypography.body(context),
          ),
          if (!widget.candidate.useCautiousCopy) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              AhaMomentCopy.helperLine,
              key: const Key('aha_moment_helper'),
              style: helperStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: 4,
            children: [
              _action(
                context,
                key: const Key('aha_moment_show_evidence'),
                label: AhaMomentCopy.showEvidenceLabel,
                onTap: _showEvidence,
              ),
              _action(
                context,
                key: const Key('aha_moment_not_related'),
                label: MemoryControlCopy.notRelatedLabel,
                onTap: _notRelated,
              ),
              _action(
                context,
                key: const Key('aha_moment_not_important'),
                label: MemoryPriorityCopy.notImportantLabel,
                onTap: _notImportant,
              ),
            ],
          ),
          AhaMomentFeedbackRow(
            candidate: widget.candidate,
            source: widget.source,
            onFeedback: () async {
              AhaMomentSession.dismiss();
              await _complete(
                analyticsEvent: ActivationFunnelAnalytics.ahaMomentUseful,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton(
      key: key,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: AppColors.textSecondary,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}