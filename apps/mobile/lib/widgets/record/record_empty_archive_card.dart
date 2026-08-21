import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/record/record_screen_framing_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Calm empty-archive card on the Record tab — count 0 only.
class RecordEmptyArchiveCard extends StatelessWidget {
  const RecordEmptyArchiveCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('record_empty_archive_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RecordScreenFramingCopy.emptyArchiveTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            RecordScreenFramingCopy.emptyArchiveBody,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: VoiceMemoryColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordScreenFramingCopy.emptyArchiveFootnote,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: VoiceMemoryColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// One-entry started state — no pattern or repeat language.
class RecordArchiveStartedCard extends StatelessWidget {
  const RecordArchiveStartedCard({required this.onAddMoment, super.key});

  final VoidCallback onAddMoment;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('record_archive_started_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RecordScreenFramingCopy.archiveStartedTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            RecordScreenFramingCopy.archiveStartedBody,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: VoiceMemoryColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('record_archive_started_cta'),
              onPressed: onAddMoment,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text(RecordScreenFramingCopy.archiveStartedCta),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two–three entries without enough repeated language yet.
class RecordArchiveWeakCompareCard extends StatelessWidget {
  const RecordArchiveWeakCompareCard({required this.onAddMoment, super.key});

  final VoidCallback onAddMoment;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('record_archive_weak_compare_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RecordScreenFramingCopy.archiveStartedTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            RecordScreenFramingCopy.weakCompareBody,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: VoiceMemoryColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordScreenFramingCopy.weakCompareFootnote,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: VoiceMemoryColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('record_archive_weak_compare_cta'),
              onPressed: onAddMoment,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text(RecordScreenFramingCopy.archiveStartedCta),
            ),
          ),
        ],
      ),
    );
  }
}