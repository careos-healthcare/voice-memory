import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/guided_thread_plan_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact "yesterday → today" plan: what is already covered, what is worth
/// checking, and one small next recording. A glance, not a task list.
/// Renders nothing without a real plan.
class GuidedThreadPlanCard extends StatelessWidget {
  const GuidedThreadPlanCard({super.key, required this.plan});

  final GuidedThreadPlan plan;

  @override
  Widget build(BuildContext context) {
    if (!plan.hasPlan) return const SizedBox.shrink();

    return Container(
      key: const Key('guided_thread_plan_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4F8F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  plan.title,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            plan.basedOnLine,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _sectionHeading(context, GuidedThreadPlan.alreadyCoveredHeading),
          for (final line in plan.alreadyCovered)
            _itemLine(context, Icons.check, line),
          for (final snippet in plan.evidenceSnippets)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs, left: 24),
              child: Text(
                '\u201C$snippet\u201D',
                style: ArchiveMobileTypography.responsiveHelper(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          _sectionHeading(context, GuidedThreadPlan.worthCheckingHeading),
          for (final line in plan.worthChecking)
            _itemLine(context, Icons.east, line),
          const SizedBox(height: AppSpacing.sm),
          _sectionHeading(context, GuidedThreadPlan.nextRecordingHeading),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                plan.nextPrompt,
                style: ArchiveMobileTypography.body(
                  context,
                ).copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            plan.encouragementLine,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              key: const Key('guided_thread_plan_record_cta'),
              onPressed: () => _openRecordWithPrompt(context),
              child: const Text(
                GuidedThreadPlan.recordCtaLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String heading) {
    return Text(
      heading,
      style: ArchiveMobileTypography.responsiveHelper(
        context,
      ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
    );
  }

  Widget _itemLine(BuildContext context, IconData icon, String line) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              line,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// Hands the next prompt to the Record screen using the existing
  /// `?prompt=` deep-link pattern — same handoff the thread follow-up uses.
  void _openRecordWithPrompt(BuildContext context) {
    final prompt = plan.nextPrompt.trim();
    if (prompt.isEmpty) {
      context.go('/record');
      return;
    }
    context.go('/record?prompt=${Uri.encodeComponent(prompt)}');
  }
}
