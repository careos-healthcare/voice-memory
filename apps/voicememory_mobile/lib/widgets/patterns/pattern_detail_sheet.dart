import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/archive_controls/archive_control_copy.dart';
import '../../features/beta_activation/beta_activation_summary_tracker.dart';
import '../../features/belief_change/belief_change_moment_engine.dart';
import '../../features/belief_change/belief_change_moment_model.dart';
import '../../features/pattern_correction/pattern_correction_copy.dart';
import '../../features/pattern_correction/pattern_correction_gates.dart';
import '../../features/pattern_confidence/pattern_confidence_engine.dart';
import '../../features/pattern_lifecycle/pattern_lifecycle_engine.dart';
import '../../features/quiet_signal/quiet_signal_engine.dart';
import '../../features/quiet_signal/quiet_signal_model.dart';
import '../../features/what_changed/what_changed_v2_copy.dart';
import '../../features/what_changed/what_changed_v2_engine.dart';
import '../../features/pattern_detail/pattern_detail_copy.dart';
import '../../features/pattern_detail/pattern_detail_model.dart';
import '../../features/pro_memory/pro_memory_boundary_copy.dart';
import '../../features/pro_memory/pro_memory_boundary_engine.dart';
import '../../features/private_report/private_report_copy.dart';
import '../../features/private_report/private_report_engine.dart';
import '../../features/share_card/share_card_model.dart';
import '../../features/transcript_correction/transcript_correction_copy.dart';
import '../../models/journal_entry.dart';
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
import 'pattern_confidence_badge.dart';
import 'pattern_lifecycle_badge.dart';
import '../common/contextual_privacy_reassurance.dart';
import 'pattern_correction_sheet.dart';

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

  Future<void> _openPatternCorrection(
    BuildContext context,
    PatternDetailResult detail,
  ) async {
    final entries = widget.buildInput?.entries ?? const <JournalEntry>[];
    if (!PatternCorrectionGates.shouldShowForPatternDetail(
      detail: detail,
      entries: entries,
      viewingConfirmedRepeatOrTimeline:
          widget.buildInput?.viewingConfirmedRepeatOrTimeline ?? true,
    )) {
      return;
    }

    await PatternCorrectionSheet.show(
      context,
      contextData: PatternCorrectionGates.buildForPatternDetail(
        detail: detail,
        entryCount: _entryCount,
        entries: entries,
        onMomentChanged: _reloadDetail,
      ),
    );
  }

  Future<void> _openPrivateReport(BuildContext context) async {
    final input = widget.buildInput;
    final entries = input?.entries ?? await AppServices.instance.journal.loadAll();
    if (!mounted) return;

    await PrivateReportEngine.showSheet(
      context,
      entries: entries,
      source: 'pattern_detail',
      isPro: widget.isPro,
      returnChecks: input?.returnChecks ?? const [],
      viewingConfirmedRepeatOrTimeline:
          input?.viewingConfirmedRepeatOrTimeline ?? true,
      triggerCapturedMilestone: input?.triggerCapturedMilestone ?? false,
      helpfulActionCapturedMilestone:
          input?.helpfulActionCapturedMilestone ?? false,
    );
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
    final patternConfidence = widget.buildInput == null
        ? null
        : PatternConfidenceEngine.build(
            entries: widget.buildInput!.entries,
            returnChecks: widget.buildInput!.returnChecks,
            changeProof: widget.buildInput!.changeProof,
            helpfulActionCapturedMilestone:
                widget.buildInput!.helpfulActionCapturedMilestone,
            viewingConfirmedRepeatOrTimeline:
                widget.buildInput!.viewingConfirmedRepeatOrTimeline,
            hideNotEnoughYet: true,
          );
    final patternLifecycle = widget.buildInput == null
        ? null
        : PatternLifecycleEngine.build(
            entries: widget.buildInput!.entries,
            returnChecks: widget.buildInput!.returnChecks,
            changeProof: widget.buildInput!.changeProof,
            helpfulActionCapturedMilestone:
                widget.buildInput!.helpfulActionCapturedMilestone,
            viewingConfirmedRepeatOrTimeline:
                widget.buildInput!.viewingConfirmedRepeatOrTimeline,
            confirmedRepeat: widget.buildInput!.confirmedRepeat,
          );
    final quietSignal = widget.buildInput == null
        ? null
        : QuietSignalEngine.build(entries: widget.buildInput!.entries);

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
              if (patternConfidence != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PatternConfidenceBadge(
                  confidence: patternConfidence,
                  showBody: true,
                ),
              ],
              if (patternLifecycle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PatternLifecycleBadge(
                  lifecycle: patternLifecycle,
                  entryCount: _entryCount,
                  source: 'pattern_detail',
                ),
              ],
              if (quietSignal != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _QuietSignalDetailSection(signal: quietSignal),
              ],
              const SizedBox(height: AppSpacing.sm),
              ContextualPrivacyReassurance(
                source: 'pattern_detail',
                entryCount: _entryCount,
                compact: false,
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
              if (PatternCorrectionGates.shouldShowForPatternDetail(
                detail: detail,
                entries: widget.buildInput?.entries ?? const [],
                viewingConfirmedRepeatOrTimeline:
                    widget.buildInput?.viewingConfirmedRepeatOrTimeline ?? true,
              )) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('pattern_correction_control'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openPatternCorrection(context, detail),
                    child: Text(
                      PatternCorrectionCopy.controlLabel,
                      style: ArchiveMobileTypography.responsiveHelper(context)
                          .copyWith(
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
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
                  showPrivacyReassurance: false,
                  showProPackagingBridge: false,
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
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('private_report_open_link'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _openPrivateReport(context),
                  child: Text(
                    PrivateReportCopy.openReportCta,
                    style: ArchiveMobileTypography.responsiveHelper(context)
                        .copyWith(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
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

class _QuietSignalDetailSection extends StatelessWidget {
  const _QuietSignalDetailSection({required this.signal});

  final QuietSignal signal;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textSecondary,
    );
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          signal.patternDetailHeading ?? '',
          key: const Key('pattern_detail_quiet_signal_heading'),
          style: labelStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          signal.patternDetailBody ?? '',
          key: const Key('pattern_detail_quiet_signal_body'),
          style: bodyStyle,
        ),
      ],
    );
  }
}
