import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/record/daily_mirror_copy.dart';
import '../../features/record/daily_mirror_model.dart';
import '../../features/record/daily_mirror_stage.dart';
import '../../record/record_screen_framing_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_colors.dart';

/// Renders [DailyMirrorResult] on the Record tab — one card, stage-driven copy.
class DailyMirrorRecordCard extends StatelessWidget {
  const DailyMirrorRecordCard({
    super.key,
    required this.mirror,
    required this.onPrimaryCta,
    this.showRecordCta = true,
  });

  final DailyMirrorResult mirror;
  final VoidCallback onPrimaryCta;
  final bool showRecordCta;

  @override
  Widget build(BuildContext context) {
    return switch (mirror.stage) {
      DailyMirrorStage.emptyArchive => _EmptyArchiveCard(),
      DailyMirrorStage.heardFirstMoment => _HeardFirstMomentCard(
          mirror: mirror,
          onPrimaryCta: onPrimaryCta,
          showRecordCta: showRecordCta,
        ),
      DailyMirrorStage.possibleLoop => _PossibleLoopCard(mirror: mirror),
      DailyMirrorStage.whatChanged => _WhatChangedCard(mirror: mirror),
    };
  }
}

class _EmptyArchiveCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('record_empty_archive_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
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
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: VoiceMemoryColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeardFirstMomentCard extends StatelessWidget {
  const _HeardFirstMomentCard({
    required this.mirror,
    required this.onPrimaryCta,
    this.showRecordCta = true,
  });

  final DailyMirrorResult mirror;
  final VoidCallback onPrimaryCta;
  final bool showRecordCta;

  bool get _isWeakStarted =>
      mirror.heroBody == DailyMirrorCopy.weakStartedHeroBody;

  bool get _isSafeDeep =>
      mirror.heroBody == DailyMirrorCopy.safeDeepArchiveHeroBody;

  @override
  Widget build(BuildContext context) {
    if (_isWeakStarted) {
      return Container(
        key: const Key('record_archive_weak_compare_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mirror.heroTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              mirror.heroBody,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: VoiceMemoryColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              DailyMirrorCopy.weakStartedFootnote,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: VoiceMemoryColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (showRecordCta) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('record_archive_weak_compare_cta'),
                  onPressed: onPrimaryCta,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(mirror.primaryCta),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      key: const Key('record_archive_started_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mirror.heroTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            mirror.heroBody,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: VoiceMemoryColors.textSecondary,
            ),
          ),
          if (!_isSafeDeep && showRecordCta) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('record_archive_started_cta'),
                onPressed: onPrimaryCta,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                ),
                child: Text(mirror.primaryCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PossibleLoopCard extends StatelessWidget {
  const _PossibleLoopCard({required this.mirror});

  final DailyMirrorResult mirror;

  bool get _isPhraseFallback =>
      mirror.heroTitle == DailyMirrorCopy.possibleLoopHeroTitleDefault;

  @override
  Widget build(BuildContext context) {
    if (_isPhraseFallback) {
      return Container(
        key: const Key('early_specific_insight_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mirror.heroTitle,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              mirror.heroBody,
              key: const Key('early_specific_insight_pattern'),
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: VoiceMemoryColors.textPrimary,
              ),
            ),
            if (mirror.evidenceLine case final evidence?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                evidence,
                key: const Key('early_specific_insight_evidence'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: VoiceMemoryColors.textSecondary,
                ),
              ),
            ],
            if (mirror.nextQuestion case final next?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                next,
                key: const Key('early_specific_insight_next_question'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: VoiceMemoryColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      key: const Key('early_behavior_loop_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mirror.heroTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            mirror.heroBody,
            key: const Key('early_behavior_loop_line'),
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: VoiceMemoryColors.textPrimary,
            ),
          ),
          if (mirror.evidenceLine case final evidence?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              evidence,
              key: const Key('early_behavior_loop_evidence'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: VoiceMemoryColors.textSecondary,
              ),
            ),
          ],
          if (mirror.nextQuestion case final next?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              DailyMirrorCopy.possibleLoopNextLabel,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              next,
              key: const Key('early_behavior_loop_next_check'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: VoiceMemoryColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WhatChangedCard extends StatelessWidget {
  const _WhatChangedCard({required this.mirror});

  final DailyMirrorResult mirror;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('daily_mirror_what_changed_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mirror.heroTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            mirror.heroBody,
            key: const Key('daily_mirror_what_changed_body'),
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: VoiceMemoryColors.textPrimary,
            ),
          ),
          if (mirror.evidenceLine case final evidence?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              evidence,
              key: const Key('daily_mirror_what_changed_evidence'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: VoiceMemoryColors.textSecondary,
              ),
            ),
          ],
          if (mirror.nextQuestion case final next?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              DailyMirrorCopy.possibleLoopNextLabel,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              next,
              key: const Key('daily_mirror_what_changed_next'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: VoiceMemoryColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
