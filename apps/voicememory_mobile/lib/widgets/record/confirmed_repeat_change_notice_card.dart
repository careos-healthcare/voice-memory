import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/early_archive_proof_analytics.dart';
import '../../features/early_archive/early_archive_insight_feedback_models.dart';
import '../../features/early_archive/early_archive_insight_quality_engine.dart';
import '../../features/early_archive/early_first_signal_engine.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'early_archive_insight_feedback_row.dart';
import 'early_archive_insight_why_section.dart';

/// Grounded change notice after a confirmed repeat returns softer.
class ConfirmedRepeatChangeNoticeCard extends StatelessWidget {
  const ConfirmedRepeatChangeNoticeCard({
    super.key,
    required this.notice,
    required this.onRecordWhatHelped,
    required this.onViewEvidence,
    this.analyticsSurface,
    this.entryCount,
    this.entriesForWhy,
  });

  final ConfirmedRepeatChangeNotice notice;
  final VoidCallback onRecordWhatHelped;
  final VoidCallback onViewEvidence;
  final String? analyticsSurface;
  final int? entryCount;
  final List<JournalEntry>? entriesForWhy;

  @override
  Widget build(BuildContext context) {
    final surface = analyticsSurface;
    final count = entryCount;
    if (surface != null && count != null) {
      EarlyArchiveProofAnalytics.softeningNoticeSeen(
        entryCount: count,
        surface: surface,
      );
    }
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final evidenceStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4);
    final whyReasons = entriesForWhy != null
        ? EarlyArchiveInsightQualityEngine.whyReasonsFor(
            insightType: EarlyArchiveInsightType.softeningNotice,
            entries: entriesForWhy!,
          )
        : const <String>[];

    return Container(
      key: const Key('confirmed_repeat_change_notice_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            notice.title,
            key: const Key('confirmed_repeat_change_notice_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            notice.body,
            key: const Key('confirmed_repeat_change_notice_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in notice.evidenceLines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                line,
                key: ValueKey('confirmed_repeat_change_notice_evidence_$line'),
                style: evidenceStyle,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('confirmed_repeat_change_notice_primary_cta'),
            onPressed: () {
              if (surface != null && count != null) {
                EarlyArchiveProofAnalytics.helpfulActionPromptTapped(
                  entryCount: count,
                  surface: surface,
                );
              }
              onRecordWhatHelped();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text(notice.primaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('confirmed_repeat_change_notice_view_evidence_cta'),
            onPressed: () {
              if (surface != null && count != null) {
                EarlyArchiveProofAnalytics.timelineViewEvidenceTapped(
                  entryCount: count,
                  surface: surface,
                  hasRealTimeline: EarlyArchiveProofAnalytics
                      .hasRealTimelineBeenSeenThisSession,
                );
              }
              onViewEvidence();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentPrimary,
            ),
            child: Text(notice.secondaryCta),
          ),
          if (surface != null && count != null) ...[
            EarlyArchiveInsightWhySection(
              reasons: whyReasons,
              insightKey: 'softeningNotice',
            ),
            EarlyArchiveInsightFeedbackRow(
              insightType: EarlyArchiveInsightType.softeningNotice,
              surface: surface,
              entryCount: count,
            ),
          ],
        ],
      ),
    );
  }
}
