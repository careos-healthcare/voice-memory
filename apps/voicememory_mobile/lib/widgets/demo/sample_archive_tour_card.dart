import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/demo/sample_archive_copy.dart';
import '../../features/demo/sample_archive_tour.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Compact guided tour card — sample archive only, session dismiss/collapse.
class SampleArchiveTourCard extends StatefulWidget {
  const SampleArchiveTourCard({super.key});

  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  State<SampleArchiveTourCard> createState() => _SampleArchiveTourCardState();
}

class _SampleArchiveTourCardState extends State<SampleArchiveTourCard> {
  bool get _collapsed => SampleArchiveTour.collapsedForSession;

  void _toggleCollapsed() {
    SampleArchiveTour.setCollapsedForSession(!_collapsed);
    setState(() {});
  }

  void _dismissForSession() {
    SampleArchiveTour.dismissForSession();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!SampleArchiveTour.shouldShow) {
      return const SizedBox.shrink(key: Key('sample_archive_tour_hidden'));
    }

    return Container(
      key: const Key('sample_archive_tour_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SampleArchiveTourCard._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SampleArchiveTourCard._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SampleArchiveCopy.tourLabel,
            key: const Key('sample_archive_tour_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SampleArchiveCopy.tourTitle,
            key: const Key('sample_archive_tour_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          if (_collapsed) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('sample_archive_tour_expand'),
                onPressed: _toggleCollapsed,
                child: const Text(SampleArchiveCopy.tourExpand),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            for (var index = 0; index < SampleArchiveTour.steps.length; index++) ...[
              if (index > 0) const SizedBox(height: AppSpacing.sm),
              _StepRow(
                index: index + 1,
                step: SampleArchiveTour.steps[index],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton(
                  key: const Key('sample_archive_tour_collapse'),
                  onPressed: _toggleCollapsed,
                  child: const Text(SampleArchiveCopy.tourCollapse),
                ),
                TextButton(
                  key: const Key('sample_archive_tour_dismiss'),
                  onPressed: _dismissForSession,
                  child: const Text(SampleArchiveCopy.tourDismiss),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
  });

  final int index;
  final SampleArchiveTourStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: Key('sample_archive_tour_step_$index'),
      children: [
        Text(
          '$index.',
          style: ArchiveMobileTypography.listTitle(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                key: Key('sample_archive_tour_step_${index}_title'),
                style: ArchiveMobileTypography.listTitle(context),
              ),
              const SizedBox(height: 2),
              Text(
                step.body,
                key: Key('sample_archive_tour_step_${index}_body'),
                style: ArchiveMobileTypography.listSubtitle(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
