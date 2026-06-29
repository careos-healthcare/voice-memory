import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/early_archive_return_reminder_copy.dart';
import '../../features/early_archive/early_archive_return_reminder_service.dart';
import '../../features/early_archive/early_archive_return_reminder_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Optional tomorrow-return reminder after confirmed repeat / early timeline.
class EarlyArchiveReturnReminderCard extends StatelessWidget {
  const EarlyArchiveReturnReminderCard({
    super.key,
    required this.onDismiss,
    this.source = 'patterns',
  });

  final VoidCallback onDismiss;
  final String source;

  Future<void> _onSetReminder(BuildContext context) async {
    final outcome = await EarlyArchiveReturnReminderService.schedule();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          EarlyArchiveReturnReminderService.confirmationMessage(outcome),
        ),
      ),
    );
    onDismiss();
  }

  Future<void> _onNotNow() async {
    await EarlyArchiveReturnReminderStore.instance().markNotNow();
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: Key('early_archive_return_reminder_card_$source'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4F7FB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            EarlyArchiveReturnReminderCopy.title,
            key: const Key('early_archive_return_reminder_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            EarlyArchiveReturnReminderCopy.body,
            key: const Key('early_archive_return_reminder_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('early_archive_return_reminder_primary_cta'),
            onPressed: () => _onSetReminder(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text(EarlyArchiveReturnReminderCopy.primaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('early_archive_return_reminder_secondary_cta'),
            onPressed: _onNotNow,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text(EarlyArchiveReturnReminderCopy.secondaryCta),
          ),
        ],
      ),
    );
  }
}
