import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class WatchTargetProBridgeSheet extends StatelessWidget {
  const WatchTargetProBridgeSheet({super.key, required this.onSeePro});

  static const headline = 'Track multiple recurring threads.';
  static const subtext =
      'Free tracks your primary active watch target. Pro keeps the longer '
      'trail across all recurring patterns.';

  final VoidCallback onSeePro;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSeePro,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WatchTargetProBridgeSheet(onSeePro: onSeePro),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              headline,
              key: const Key('watch_target_pro_bridge_headline'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtext,
              key: const Key('watch_target_pro_bridge_subtext'),
              style: ArchiveMobileTypography.explanationBody(
                context,
              ).copyWith(color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('watch_target_pro_bridge_see_pro'),
              onPressed: () {
                Navigator.of(context).pop();
                onSeePro();
              },
              child: const Text('See Pro'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('watch_target_pro_bridge_close'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
