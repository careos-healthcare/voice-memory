import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/tomorrow_return/active_pattern_thread_coordinator.dart';
import '../../features/tomorrow_return/active_pattern_thread_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Patterns hero card for the thread the user is continuing.
class ActivePatternThreadCard extends StatelessWidget {
  const ActivePatternThreadCard({
    super.key,
    required this.thread,
    this.compact = false,
  });

  final ActivePatternThread thread;
  final bool compact;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  Widget build(BuildContext context) {
    final badge = ActivePatternThreadCoordinator.statusBadgeLabel(thread);
    final lastChecked = ActivePatternThreadCoordinator.lastCheckedSummary(
      thread,
    );
    final chips = thread.chips.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.activePatternCurrentTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            thread.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 20,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusBadge(label: badge),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.md),
            _Section(
              label: ConsumerUiCopy.activePatternLastCheckedLabel,
              body: lastChecked,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Section(
              label: ConsumerUiCopy.activePatternNextWatchLabel,
              body: thread.nextPrompt,
            ),
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
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => context.go('/record'),
                child: const Text(ConsumerUiCopy.activePatternRecordTodayCta),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: () => context.go('/belief-changes'),
                child: const Text(ConsumerUiCopy.seeWhatChanged),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ConsumerUiCopy.activePatternPostSaveLine,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ActivePatternThreadCard._warmBorder),
      ),
      child: Text(
        label,
        style: VoiceMemoryTypography.metadataStyle(
          color: AppColors.textSecondary,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
        ),
      ],
    );
  }
}
