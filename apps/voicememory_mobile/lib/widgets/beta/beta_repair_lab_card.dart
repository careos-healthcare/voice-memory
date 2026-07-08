import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_copy.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_model.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_store.dart';
import '../../features/beta_repair_lab/beta_repair_lab_analytics.dart';
import '../../features/beta_repair_lab/beta_repair_lab_copy.dart';
import '../../features/beta_repair_lab/beta_repair_lab_engine.dart';
import '../../features/beta_repair_lab/beta_repair_lab_model.dart';
import '../../features/beta_repair_lab/beta_repair_lab_store.dart';
import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_cards.dart';

/// Beta/testing-only repair lab picker — one active repair at a time.
class BetaRepairLabCard extends StatefulWidget {
  const BetaRepairLabCard({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
  });

  final String source;
  final bool compact;

  @override
  State<BetaRepairLabCard> createState() => _BetaRepairLabCardState();
}

class _BetaRepairLabCardState extends State<BetaRepairLabCard> {
  var _trackedSeen = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await BetaRepairLabStore.ensureLoaded();
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    BetaRepairLabAnalytics.seen(source: widget.source);
  }

  Future<void> _selectMode(BetaRepairLabMode mode) async {
    final previous = await BetaRepairLabStore.selectMode(
      mode,
      source: widget.source,
    );
    if (mode == BetaRepairLabMode.none) {
      BetaRepairLabAnalytics.modeCleared(
        source: widget.source,
        previousMode: previous,
      );
    } else {
      BetaRepairLabAnalytics.modeSelected(
        source: widget.source,
        selectedMode: mode,
        previousMode: previous,
      );
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!BetaRepairLabEngine.shouldShowLab(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(key: Key('beta_repair_lab_card_hidden'));
    }
    if (!_loaded) {
      return const SizedBox.shrink(key: Key('beta_repair_lab_card_loading'));
    }

    _trackSeenOnce();

    final state = BetaRepairLabEngine.currentState();
    final bodyStyle = const TextStyle(fontSize: 12, height: 1.35);

    return Container(
      key: const Key('beta_repair_lab_card'),
      padding: EdgeInsets.all(widget.compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              BetaRepairLabCopy.cardTitle,
              key: const Key('beta_repair_lab_heading'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              BetaRepairLabCopy.cardBody,
              key: const Key('beta_repair_lab_body'),
              style: bodyStyle,
            ),
            const SizedBox(height: 8),
            Text(
              '${BetaRepairLabCopy.activeModeLabel}: ${state.activeModeLabel}',
              key: const Key('beta_repair_lab_active_mode'),
              style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              state.warning,
              key: const Key('beta_repair_lab_warning'),
              style: bodyStyle.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            for (final info in BetaRepairLabEngine.allModeInfos()) ...[
              _ModeTile(
                info: info,
                selected: state.mode == info.mode,
                onSelect: () => unawaited(_selectMode(info.mode)),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              BetaRepairLabCopy.guidanceOnlyNote,
              key: const Key('beta_repair_lab_guidance_note'),
              style: bodyStyle.copyWith(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.info,
    required this.selected,
    required this.onSelect,
  });

  final BetaRepairLabModeInfo info;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final labelStyle = const TextStyle(fontSize: 12, height: 1.35);
    return Material(
      color: selected ? AppColors.surfaceAlt : AppTheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('beta_repair_lab_mode_${info.mode.analyticsValue}'),
        onTap: onSelect,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                info.label,
                style: labelStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              Text('Fixes: ${info.fixes}', style: labelStyle),
              Text('When: ${info.whenToUse}', style: labelStyle),
              Text('Changes: ${info.changes}', style: labelStyle),
              Text('Do not touch: ${info.doNotTouch}', style: labelStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class BetaRepairLabProofCard extends StatefulWidget {
  const BetaRepairLabProofCard({
    super.key,
    required this.result,
    this.onChanged,
    this.onNotRelevantAnswered,
    this.store,
    this.skipPrefsLoad = false,
    this.initialAnswered = false,
    this.initialAnswerType,
  });

  const BetaRepairLabProofCard.test({
    super.key,
    required this.result,
    this.onChanged,
    this.onNotRelevantAnswered,
    this.store,
    bool answered = false,
    BetaProofFeedbackType? answerType,
  })  : skipPrefsLoad = true,
        initialAnswered = answered,
        initialAnswerType = answerType;

  final BetaRepairLabProofResult result;
  final VoidCallback? onChanged;
  final Future<void> Function()? onNotRelevantAnswered;
  final BetaProofFeedbackStore? store;
  final bool skipPrefsLoad;
  final bool initialAnswered;
  final BetaProofFeedbackType? initialAnswerType;

  @override
  State<BetaRepairLabProofCard> createState() => _BetaRepairLabProofCardState();
}

class _BetaRepairLabProofCardState extends State<BetaRepairLabProofCard> {
  var _answered = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _answered = widget.initialAnswered;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    await BetaProofFeedbackStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _answered = BetaProofFeedbackStore.isAnsweredToday(
        BetaProofFeedbackSurface.timelineProofMoment,
      );
    });
  }

  Future<void> _selectAnswer(BetaProofFeedbackType feedbackType) async {
    final store = widget.store ?? BetaProofFeedbackStore.instance();
    await store.saveAnswer(
      surface: BetaProofFeedbackSurface.timelineProofMoment,
      feedbackType: feedbackType,
      entryCount: widget.result.entryCount,
    );
    if (feedbackType == BetaProofFeedbackType.notRelevant) {
      await widget.onNotRelevantAnswered?.call();
    }
    if (!mounted) return;
    setState(() => _answered = true);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('beta_repair_lab_proof_card_hidden'));
    }

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: Key('beta_repair_lab_proof_card_${widget.result.variant.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('beta_repair_lab_proof_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('beta_repair_lab_proof_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          if (!_answered) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.feedbackPrompt,
              key: const Key('beta_repair_lab_proof_feedback_prompt'),
              style: ArchiveMobileTypography.cardLabel(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final type in BetaProofFeedbackType.values)
                  TextButton(
                    key: Key(
                      'beta_repair_lab_proof_option_${type.storageValue}',
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => unawaited(_selectAnswer(type)),
                    child: Text(BetaProofFeedbackCopy.labelFor(type)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class BetaRepairLabProPlacementCard extends StatefulWidget {
  const BetaRepairLabProPlacementCard({
    super.key,
    required this.result,
    required this.onSeePro,
    this.compact = false,
  });

  const BetaRepairLabProPlacementCard.test({
    super.key,
    required this.result,
    required this.onSeePro,
    this.compact = false,
  });

  final BetaRepairLabProPlacementResult result;
  final VoidCallback onSeePro;
  final bool compact;

  @override
  State<BetaRepairLabProPlacementCard> createState() =>
      _BetaRepairLabProPlacementCardState();
}

class _BetaRepairLabProPlacementCardState
    extends State<BetaRepairLabProPlacementCard> {
  var _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('beta_repair_lab_pro_placement_card_hidden'),
      );
    }

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('beta_repair_lab_pro_placement_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('beta_repair_lab_pro_placement_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            widget.result.body,
            key: const Key('beta_repair_lab_pro_placement_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          FilledButton(
            key: const Key('beta_repair_lab_pro_placement_primary_cta'),
            onPressed: widget.onSeePro,
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('beta_repair_lab_pro_placement_secondary_cta'),
            onPressed: () => setState(() => _dismissed = true),
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}
