import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:archiveme_mobile/features/trust/aha_proof_share_eligibility.dart';
import 'package:archiveme_mobile/features/trust/pro_trust_copy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Optional share card after useful aha feedback — compile-time text only.
class AhaProofShareCard extends StatelessWidget {
  const AhaProofShareCard({
    required this.entryCount, required this.onDismiss, super.key,
    this.source = 'record',
    this.onShare,
    this.onCopy,
  });

  final int entryCount;
  final VoidCallback onDismiss;
  final String source;
  final Future<void> Function(String text)? onShare;
  final Future<void> Function(String text)? onCopy;

  String get _shareText => ProTrustCopy.shareTextTemplate;

  Future<void> _copy(BuildContext context) async {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.ahaProofShareCopied,
      entryCount: entryCount,
      source: source,
      stage: ProTrustStage.ahaProofShare,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    if (onCopy != null) {
      await onCopy!(_shareText);
      return;
    }
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: _shareText,
    );
    if (!context.mounted) return;
    ArchiveShareActions.trackShareAction(
      source: source,
      cardType: 'aha_proof_share',
      shareType: 'copy',
      status: ArchiveShareActions.outcomeStatus(outcome),
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  Future<void> _share(BuildContext context) async {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.ahaProofShareTapped,
      entryCount: entryCount,
      source: source,
      stage: ProTrustStage.ahaProofShare,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    if (onShare != null) {
      await onShare!(_shareText);
      return;
    }
    final outcome = await ArchiveShareActions.shareShareText(
      context,
      text: _shareText,
    );
    if (!context.mounted) return;
    ArchiveShareActions.trackShareAction(
      source: source,
      cardType: 'aha_proof_share',
      shareType: outcome == ArchiveShareOutcome.fallbackCopied
          ? 'fallback_copy'
          : 'share',
      status: ArchiveShareActions.outcomeStatus(outcome),
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AhaProofShareEligibility.shouldShow) {
      return const SizedBox.shrink();
    }

    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.ahaProofShareSeen,
      entryCount: entryCount,
      source: source,
      stage: ProTrustStage.ahaProofShare,
      memoryScope: MemoryScopePolicy.scope.id,
      oncePerSession: true,
    );
    AhaProofShareEligibility.markShown();

    final shareEnabled = ArchiveShareActions.isShareable(_shareText);

    return Container(
      key: const Key('aha_proof_share_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F4FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProTrustCopy.shareTitle,
            key: const Key('aha_proof_share_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProTrustCopy.shareBody,
            key: const Key('aha_proof_share_body'),
            style: ArchiveMobileTypography.body(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _shareText,
            key: const Key('aha_proof_share_template'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('aha_proof_share_not_now'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.ahaProofShareDismissed,
                      entryCount: entryCount,
                      source: source,
                      stage: ProTrustStage.ahaProofShare,
                      memoryScope: MemoryScopePolicy.scope.id,
                    );
                    AhaProofShareEligibility.dismiss();
                    onDismiss();
                  },
                  child: const Text(ProTrustCopy.shareNotNow),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton(
                  key: const Key('aha_proof_share_copy'),
                  onPressed: shareEnabled ? () => _copy(context) : null,
                  child: const Text(ProTrustCopy.shareCopyCta),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('aha_proof_share_cta'),
                  onPressed: shareEnabled ? () => _share(context) : null,
                  child: const Text(ProTrustCopy.shareCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}