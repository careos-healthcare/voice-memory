import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/archive_controls/archive_control_copy.dart';
import '../../features/beta_activation/beta_activation_summary_tracker.dart';
import '../../features/belief_change/belief_change_moment_engine.dart';
import '../../features/belief_change/belief_change_moment_model.dart';
import '../../features/pattern_detail/pattern_detail_copy.dart';
import '../../features/what_changed/what_changed_v2_copy.dart';
import '../../features/what_changed/what_changed_v2_engine.dart';
import '../../features/pattern_detail/pattern_detail_model.dart';
import '../../features/pro_memory/pro_memory_boundary_copy.dart';
import '../../features/pro_memory/pro_memory_boundary_engine.dart';
import '../../features/share_card/share_card_model.dart';
import '../../features/transcript_correction/transcript_correction_copy.dart';
import '../archive_controls/archive_moment_actions_sheet.dart';
import '../archive_controls/archive_pattern_exclusion_actions.dart';
import '../../services/app_services.dart';
import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../archive_paywall/pro_memory_upgrade_bridge.dart';
import '../record/correct_transcript_sheet.dart';
import '../record/entry_importance_button.dart';
import '../share_card/share_card_action_card.dart';
import 'belief_change_moment_card.dart';

/// Bottom sheet explaining one confirmed pattern and its evidence.
class PatternDetailSheet extends StatefulWidget {
  const PatternDetailSheet({
    super.key,
    required this.detail,
    this.buildInput,
    this.entryCount = 0,
    this.isPro = true,
    this.onSeePro,
    this.shareCard,
  });

  final PatternDetailResult detail;
  final PatternDetailBuildInput? buildInput;
  final int entryCount;
  final bool isPro;
  final VoidCallback? onSeePro;
  final ShareCardModel? shareCard;

  static Future<void> show(
    BuildContext context, {
    required PatternDetailResult detail,
    PatternDetailBuildInput? buildInput,
    int entryCount = 0,
    bool isPro = true,
    VoidCallback? onSeePro,
    ShareCardModel? shareCard,
  }) {
    unawaited(BetaActivationSummaryTracker.trackPatternDetailsOpened());
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: PatternDetailSheet(
          detail: detail,
          buildInput: buildInput,
          entryCount: entryCount,
          isPro: isPro,
          onSeePro: onSeePro,
          shareCard: shareCard,
        ),
      ),
    );
  }

  @override
  State<PatternDetailSheet> createState() => _PatternDetailSheetState();
}

class _PatternDetailSheetState extends State<PatternDetailSheet> {
  late PatternDetailResult? _detail;
  late int _entryCount;
  bool _belowThreshold = false;

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    _entryCount = widget.entryCount;
  }

  Future<void> _reloadDetail() async {
    final input = widget.buildInput;
    if (input == null || !AppServices.isInitialized) return;
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    final rebuilt = PatternDetailBuildInput(
      entries: entries,
      confirmedRepeat: input.confirmedRepeat,
      changeProof: input.changeProof,
      returnChecks: input.returnChecks,
      triggerCapturedMilestone: input.triggerCapturedMilestone,
      helpfulActionCapturedMilestone: input.helpfulActionCapturedMilestone,
      viewingConfirmedRepeatOrTimeline: input.viewingConfirmedRepeatOrTimeline,
    ).buildDetail();
    setState(() {
      _entryCount = entries.length;
      _detail = rebuilt;
      _belowThreshold = rebuilt == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_belowThreshold || _detail == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Text(
            ArchiveControlCopy.patternNeedsMoreEvidenceFallback,
            key: const Key('pattern_detail_needs_more_evidence'),
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final detail = _detail!;
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final labelStyle = ArchiveMobileTypography.cardLabel(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);
    final fallbackStyle = secondaryStyle.copyWith(fontStyle: FontStyle.italic);
    final visibleMoments = ProMemoryBoundaryEngine.visibleRecentMoments(
      moments: detail.savedMoments,
      isPro: widget.isPro,
    );
    final gatedOlderCount = ProMemoryBoundaryEngine.gatedOlderMomentCount(
      totalMomentCount: detail.savedMoments.length,
      isPro: widget.isPro,
    );
    final beliefChangeMoment = widget.buildInput == null
        ? null
        : BeliefChangeMomentEngine.build(
            entries: widget.buildInput!.entries,
            changeProof: widget.buildInput!.changeProof,
            returnChecks: widget.buildInput!.returnChecks,
            helpfulActionCapturedMilestone:
                widget.buildInput!.helpfulActionCapturedMilestone,
            viewingConfirmedRepeatOrTimeline:
                widget.buildInput!.viewingConfirmedRepeatOrTimeline,
          );
    final whatChangedPayoff = widget.buildInput == null
        ? null
        : WhatChangedV2Engine.buildAnsweredPayoff(
            entries: widget.buildInput!.entries,
          );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('pattern_detail_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PatternDetailCopy.sheetTitle,
                key: const Key('pattern_detail_sheet_title'),
                style: titleStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.patternLabelHeading,
                key: const Key('pattern_detail_pattern_label_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.patternLabel,
                key: const Key('pattern_detail_pattern_label'),
                style: bodyStyle,
              ),
              if (detail.showWhyThisMatters) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  PatternDetailCopy.whyThisMattersHeading,
                  key: const Key('pattern_detail_why_this_matters_heading'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  PatternDetailCopy.whyThisMattersBody,
                  key: const Key('pattern_detail_why_this_matters_body'),
                  style: secondaryStyle,
                ),
              ],
              if (beliefChangeMoment != null) ...[
                const SizedBox(height: AppSpacing.md),
                BeliefChangeMomentCard(
                  moment: beliefChangeMoment,
                  entryCount: _entryCount,
                  source: 'pattern_detail',
                  compact: true,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.evidenceHeading,
                key: const Key('pattern_detail_evidence_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                PatternDetailCopy.evidenceIntro,
                key: const Key('pattern_detail_evidence_intro'),
                style: secondaryStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final phrase in detail.evidencePhrases) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: bodyStyle),
                    Expanded(
                      child: Text(
                        '"$phrase"',
                        key: Key('pattern_detail_evidence_phrase_$phrase'),
                        style: bodyStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.whatChangedHeading,
                key: const Key('pattern_detail_what_changed_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
            Text(
              detail.whatChangedBody,
              key: const Key('pattern_detail_what_changed_body'),
              style: detail.whatChangedSupported ? bodyStyle : fallbackStyle,
            ),
            if (whatChangedPayoff != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                whatChangedPayoff.payoffLine,
                key: const Key('pattern_detail_what_changed_payoff'),
                style: secondaryStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                WhatChangedV2Copy.thenLabel,
                key: const Key('pattern_detail_what_changed_then_label'),
                style: labelStyle,
              ),
              Text(
                WhatChangedV2Copy.formatSnippet(
                  whatChangedPayoff.comparison.thenSnippet,
                ),
                key: const Key('pattern_detail_what_changed_then_snippet'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                WhatChangedV2Copy.nowLabel,
                key: const Key('pattern_detail_what_changed_now_label'),
                style: labelStyle,
              ),
              Text(
                WhatChangedV2Copy.formatSnippet(
                  whatChangedPayoff.comparison.nowSnippet,
                ),
                key: const Key('pattern_detail_what_changed_now_snippet'),
                style: bodyStyle,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.whatHelpedHeading,
                key: const Key('pattern_detail_what_helped_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.whatHelpedBody,
                key: const Key('pattern_detail_what_helped_body'),
                style: detail.whatHelpedSupported ? bodyStyle : fallbackStyle,
              ),
              if (detail.hasSavedMoments) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  PatternDetailCopy.savedMomentsHeading,
                  key: const Key('pattern_detail_saved_moments_heading'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < visibleMoments.length; i++)
                  _MomentRow(
                    moment: visibleMoments[i],
                    index: i,
                    patternKey: detail.patternKey,
                    entryCount: _entryCount,
                    onMomentChanged: _reloadDetail,
                  ),
                if (gatedOlderCount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    ProMemoryBoundaryCopy.olderEvidenceTitle,
                    key: const Key('pattern_detail_older_evidence_title'),
                    style: labelStyle,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ProMemoryBoundaryCopy.olderEvidenceBody,
                    key: const Key('pattern_detail_older_evidence_body'),
                    style: secondaryStyle,
                  ),
                  if (widget.onSeePro != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ProMemoryUpgradeBridge(
                      compact: true,
                      showNotNow: false,
                      onSeePro: widget.onSeePro!,
                    ),
                  ],
                ],
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.whatToWatchHeading,
                key: const Key('pattern_detail_what_to_watch_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.whatToWatchNextBody,
                key: const Key('pattern_detail_what_to_watch_body'),
                style: bodyStyle,
              ),
              if (widget.shareCard != null) ...[
                const SizedBox(height: AppSpacing.md),
                ShareCardActionCard(
                  model: widget.shareCard!,
                  source: 'pattern_detail',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentRow extends StatefulWidget {
  const _MomentRow({
    required this.moment,
    required this.index,
    required this.patternKey,
    required this.entryCount,
    required this.onMomentChanged,
  });

  final PatternDetailMoment moment;
  final int index;
  final String patternKey;
  final int entryCount;
  final Future<void> Function() onMomentChanged;

  @override
  State<_MomentRow> createState() => _MomentRowState();
}

class _MomentRowState extends State<_MomentRow> {
  PatternDetailMoment get moment => widget.moment;
  int get index => widget.index;

  Future<void> _openCorrection(BuildContext context) async {
    final entry =
        await AppServices.instance.journalStore.getById(moment.entryId);
    if (entry == null || !context.mounted) return;
    final updated = await TranscriptCorrection.open(
      context,
      entry: entry,
      source: 'pattern_detail_sheet',
      entryCount: widget.entryCount,
    );
    if (updated == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(TranscriptCorrectionCopy.savedSuccess)),
    );
    await widget.onMomentChanged();
  }

  Future<void> _excludeFromPattern(BuildContext context) async {
    final result = await ArchivePatternExclusionActions.excludeFromPattern(
      context: context,
      entryId: moment.entryId,
      patternKey: widget.patternKey,
      source: 'pattern_detail_sheet',
    );
    if (result?.excluded == true) {
      await widget.onMomentChanged();
    }
  }

  Future<void> _deleteMoment(BuildContext context) async {
    final result = await ArchiveMomentDeleteActions.deleteMoment(
      context: context,
      entryId: moment.entryId,
      source: 'pattern_detail_sheet',
    );
    if (result?.deleted == true) {
      await widget.onMomentChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textPrimary,
    );
    final previewStyle =
        ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final chipStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.accentPrimary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        key: Key('pattern_detail_moment_row_$index'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  moment.dateTimeLabel,
                  key: Key('pattern_detail_moment_date_$index'),
                  style: labelStyle,
                ),
              ),
              Container(
                key: Key('pattern_detail_moment_chip_$index'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  moment.statusChipLabel,
                  style: chipStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            moment.previewText,
            key: Key('pattern_detail_moment_preview_$index'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: previewStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('pattern_detail_correct_transcript_$index'),
              onPressed: () => unawaited(_openCorrection(context)),
              child: const Text(TranscriptCorrectionCopy.actionLabel),
            ),
          ),
          if (moment.statusKey == 'used_as_evidence') ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key('pattern_detail_exclude_from_pattern_$index'),
                onPressed: () => unawaited(_excludeFromPattern(context)),
                child: const Text(ArchiveControlCopy.excludeFromPatternButton),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('pattern_detail_delete_moment_$index'),
              onPressed: () => unawaited(_deleteMoment(context)),
              child: const Text(ArchiveControlCopy.deleteMomentButton),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          EntryImportanceButton(
            entryId: moment.entryId,
            source: 'pattern_detail_sheet',
            entryCount: widget.entryCount,
            compact: true,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}
