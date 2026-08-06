import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta/beta_activation_loop_tracker.dart';
import '../../features/early_archive/early_archive_proof_analytics.dart';
import '../../features/early_archive/early_archive_insight_feedback_models.dart';
import '../../features/early_archive/early_archive_insight_quality_engine.dart';
import '../../features/early_archive/early_first_signal_engine.dart';
import '../../features/pattern_confidence/pattern_confidence_model.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'early_archive_insight_feedback_row.dart';
import 'early_archive_insight_why_section.dart';
import '../patterns/pattern_confidence_badge.dart';

/// Early archive card for 1–3 saved moments — receipt, first signal, or confirmation.
class EarlyFirstSignalCard extends StatelessWidget {
  const EarlyFirstSignalCard({
    super.key,
    required this.signal,
    required this.onPrimary,
    this.onViewEvidence,
    this.onReturnPrompt,
    this.showPrimaryCta = true,
    this.analyticsSurface,
    this.entryCount,
    this.entriesForWhy,
    this.showInsightFeedback = true,
    this.patternConfidence,
  });

  final EarlyFirstSignalModel signal;
  final VoidCallback onPrimary;
  final VoidCallback? onViewEvidence;
  final VoidCallback? onReturnPrompt;
  final bool showPrimaryCta;
  final String? analyticsSurface;
  final int? entryCount;
  final List<JournalEntry>? entriesForWhy;
  final bool showInsightFeedback;
  final PatternConfidence? patternConfidence;

  void _trackSeen() {
    final surface = analyticsSurface;
    final count = entryCount;
    if (surface == null || count == null) return;
    switch (signal.kind) {
      case EarlyFirstSignalKind.oneEntryReceipt:
        EarlyArchiveProofAnalytics.heardReceiptSeen(
          entryCount: count,
          surface: surface,
        );
      case EarlyFirstSignalKind.twoEntryFirstSignal:
        EarlyArchiveProofAnalytics.possiblePatternSeen(
          entryCount: count,
          surface: surface,
        );
      case EarlyFirstSignalKind.threeEntryConfirmedRepeat:
        EarlyArchiveProofAnalytics.confirmedRepeatSeen(
          entryCount: count,
          surface: surface,
        );
      case EarlyFirstSignalKind.twoEntryNoPattern:
        unawaited(BetaActivationLoopTracker.trackTwoEntryUnrelatedSeen());
        break;
    }
  }

  void _trackViewEvidence() {
    final surface = analyticsSurface;
    final count = entryCount;
    if (surface == null || count == null) return;
    EarlyArchiveProofAnalytics.timelineViewEvidenceTapped(
      entryCount: count,
      surface: surface,
      hasRealTimeline:
          EarlyArchiveProofAnalytics.hasRealTimelineBeenSeenThisSession,
    );
  }

  void _trackTriggerPrompt() {
    final surface = analyticsSurface;
    final count = entryCount;
    if (surface == null || count == null) return;
    EarlyArchiveProofAnalytics.triggerPromptTapped(
      entryCount: count,
      surface: surface,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeen();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary);
    final evidenceStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4);
    final timestampStyle = ArchiveMobileTypography.cardLabel(context);
    final returnPrompt = signal.returnPrompt;
    final whyReasons = signal.showsConfirmedRepeat && entriesForWhy != null
        ? EarlyArchiveInsightQualityEngine.whyReasonsFor(
            insightType: EarlyArchiveInsightType.confirmedRepeat,
            entries: entriesForWhy!,
          )
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: ValueKey('early_first_signal_card_${signal.kind.name}'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: VoiceMemoryCards.standard(
            background: const Color(0xFFFFFBF5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                signal.title,
                key: const Key('early_first_signal_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              if (patternConfidence != null) ...[
                const SizedBox(height: AppSpacing.xs),
                PatternConfidenceBadge(confidence: patternConfidence!),
              ],
              for (final line in signal.lines) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  line,
                  key: ValueKey('early_first_signal_line_$line'),
                  style: bodyStyle,
                ),
              ],
              if (signal.evidenceHeading != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  signal.evidenceHeading!,
                  key: const Key('early_first_signal_evidence_heading'),
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
              ],
              if (signal.evidencePhrases.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  key: const Key('early_first_signal_evidence_phrases'),
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final phrase in signal.evidencePhrases)
                      Chip(
                        key: ValueKey(
                          'early_first_signal_evidence_phrase_$phrase',
                        ),
                        label: Text(phrase),
                        backgroundColor: const Color(0xFFF4F7F4),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        labelStyle: evidenceStyle,
                      ),
                  ],
                ),
              ],
              if (signal.evidenceSupportLine != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  signal.evidenceSupportLine!,
                  key: const Key('early_first_signal_evidence_support'),
                  style: bodyStyle,
                ),
              ],
              if (signal.evidencePhrases.isEmpty &&
                  signal.evidenceRows.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                for (final row in signal.evidenceRows)
                  Padding(
                    key: ValueKey(
                      'early_first_signal_evidence_${row.timestampLabel}',
                    ),
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.timestampLabel, style: timestampStyle),
                        const SizedBox(height: 2),
                        Text(row.snippet, style: evidenceStyle),
                      ],
                    ),
                  ),
              ],
              if (showPrimaryCta) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const Key('early_first_signal_primary_cta'),
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(signal.primaryCta),
                ),
              ],
              if (signal.secondaryCta != null && onViewEvidence != null) ...[
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  key: const Key('early_first_signal_view_evidence_cta'),
                  onPressed: () {
                    _trackViewEvidence();
                    onViewEvidence!();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                  ),
                  child: Text(signal.secondaryCta!),
                ),
              ],
              if (signal.showsConfirmedRepeat &&
                  showInsightFeedback &&
                  analyticsSurface != null &&
                  entryCount != null) ...[
                EarlyArchiveInsightWhySection(
                  reasons: whyReasons,
                  insightKey: 'confirmedRepeat',
                ),
                EarlyArchiveInsightFeedbackRow(
                  insightType: EarlyArchiveInsightType.confirmedRepeat,
                  surface: analyticsSurface!,
                  entryCount: entryCount!,
                ),
              ],
            ],
          ),
        ),
        if (returnPrompt != null && onReturnPrompt != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _ConfirmedRepeatReturnPromptSection(
            prompt: returnPrompt,
            onCta: () {
              _trackTriggerPrompt();
              onReturnPrompt!();
            },
          ),
        ],
      ],
    );
  }
}

class _ConfirmedRepeatReturnPromptSection extends StatelessWidget {
  const _ConfirmedRepeatReturnPromptSection({
    required this.prompt,
    required this.onCta,
  });

  final EarlyFirstSignalReturnPrompt prompt;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('confirmed_repeat_return_prompt'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            prompt.title,
            key: const Key('confirmed_repeat_return_prompt_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(
              context,
            ).copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            prompt.body,
            key: const Key('confirmed_repeat_return_prompt_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('confirmed_repeat_return_prompt_cta'),
            onPressed: onCta,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentPrimary,
            ),
            child: Text(prompt.cta),
          ),
        ],
      ),
    );
  }
}
