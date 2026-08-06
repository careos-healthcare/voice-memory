import 'package:flutter/material.dart';

import '../../features/tomorrow_return/watch_for_coordinator.dart';
import '../../features/tomorrow_return/watch_for_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Patterns card for the latest completed watch-for follow-up.
class WatchForResultCard extends StatelessWidget {
  const WatchForResultCard({
    super.key,
    required this.completed,
    this.headline,
    this.body,
    this.footer,
  });

  final WatchForItem completed;
  final String? headline;
  final String? body;
  final String? footer;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  Widget build(BuildContext context) {
    final title = headline ?? WatchForCoordinator.headlineFor(completed);
    final detail = body ?? _defaultBody(completed);
    final foot = footer ?? WatchForCoordinator.footerLineFor(completed.result);
    final chips = completed.chips.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.watchForResultCardTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              detail,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(height: 1.45),
            ),
          ],
          if (foot.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              foot,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(height: 1.4, fontStyle: FontStyle.italic),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (c) => Chip(
                      label: Text(c),
                      backgroundColor: AppColors.backgroundSecondary,
                      side: const BorderSide(color: _warmBorder),
                      labelStyle: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 13),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _defaultBody(WatchForItem item) {
    if ((item.comparisonHint ?? '').isNotEmpty) {
      return WatchForCoordinator.bodyForCompletedItem(item);
    }
    final watch = item.displaySpecificPrompt.trim().isNotEmpty
        ? item.displaySpecificPrompt
        : item.text.trim();
    final label = watch.startsWith('Tomorrow, notice ')
        ? watch.substring('Tomorrow, notice '.length)
        : watch.startsWith('whether ')
        ? watch.substring(8)
        : watch;
    switch (item.result) {
      case WatchForResult.showedAgain:
        return 'Yesterday you were watching for $label. Today it showed up again.';
      case WatchForResult.didNotShow:
        return 'Yesterday you were watching for $label. It did not show up in today\'s moment.';
      case WatchForResult.changedShape:
        return 'Yesterday you were watching for $label. Today it changed shape in what you said.';
      case WatchForResult.unclear:
        return ConsumerUiCopy.watchForResultBodyUnclear;
      case WatchForResult.none:
        return '';
    }
  }
}
