import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_improvement/beta_improvement_pack_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:archiveme_mobile/features/early_archive/post_save_return_handoff_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Post-save return guidance after entry 1 or 2 — no extra CTAs.
class PostSaveReturnHandoffCard extends StatelessWidget {
  const PostSaveReturnHandoffCard({
    required this.handoff, required this.entryCount, super.key,
  });

  final PostSaveReturnHandoff handoff;
  final int entryCount;

  void _trackSeen() {
    EarlyArchiveProofAnalytics.postSaveReturnHandoffSeen(
      entryCount: entryCount,
      stage: handoff.analyticsStage,
      hasPhrase: handoff.hasPhrase,
      relationState: handoff.analyticsRelationState,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeen();
    return Container(
      key: Key('post_save_return_handoff_card_${handoff.stage.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            handoff.title,
            key: const Key('post_save_return_handoff_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            handoff.body,
            key: const Key('post_save_return_handoff_body'),
            style: ArchiveMobileTypography.explanationBody(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            handoff.footer,
            key: const Key('post_save_return_handoff_footer'),
            style: ArchiveMobileTypography.explanationBody(
              context,
            ).copyWith(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (BetaImprovementPackEngine.returnThreeDayPlan(
                entryCount: entryCount,
              ) !=
              null) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final line in BetaImprovementPackEngine.returnThreeDayPlan(
              entryCount: entryCount,
            )!)
              Text(
                line,
                key: Key('post_save_return_plan_${line.hashCode}'),
                style: ArchiveMobileTypography.explanationBody(
                  context,
                ).copyWith(color: AppColors.textSecondary, fontSize: 13),
              ),
          ],
        ],
      ),
    );
  }
}