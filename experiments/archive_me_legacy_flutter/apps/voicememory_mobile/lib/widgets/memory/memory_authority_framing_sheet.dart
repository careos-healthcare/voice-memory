import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_authority_frame.dart';
import '../../features/memory/memory_influence_level.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// "How this memory was used" — the high-level explanation of the
/// authority frame behind a memory card.
///
/// Every line is a compile-time constant chosen by influence level: no
/// notes, transcripts, snippets, entry ids, dates, names, or private
/// phrases can ever appear here, and no scores or percentages are shown.
class MemoryAuthorityFramingSheet extends StatelessWidget {
  const MemoryAuthorityFramingSheet({super.key, required this.frame});

  final MemoryAuthorityFrame frame;

  static Future<void> show(BuildContext context, MemoryAuthorityFrame frame) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryAuthorityFramingOpened,
      authorityState: frame.authorityState.id,
      influenceLevel: frame.influenceLevel.id,
      reasonId: frame.reasonId,
      cardType: frame.cardType,
    );
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MemoryAuthorityFramingSheet(frame: frame),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        key: const Key('memory_authority_framing_sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MemoryAuthorityCopy.sheetTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _pill(context, frame.influenceLevel.label),
                _pill(context, frame.authorityState.label),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              MemoryAuthorityCopy.bodyFor(frame.influenceLevel),
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              MemoryAuthorityCopy.sheetFooter,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
