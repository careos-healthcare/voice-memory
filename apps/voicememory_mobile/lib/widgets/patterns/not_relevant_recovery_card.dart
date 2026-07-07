import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/not_relevant_recovery/not_relevant_recovery_analytics.dart';
import '../../features/not_relevant_recovery/not_relevant_recovery_copy.dart';
import '../../features/not_relevant_recovery/not_relevant_recovery_engine.dart';
import '../../features/not_relevant_recovery/not_relevant_recovery_model.dart';
import '../../features/not_relevant_recovery/not_relevant_recovery_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Makes not-relevant correction visible and lets users refine timeline weight.
class NotRelevantRecoveryCard extends StatefulWidget {
  const NotRelevantRecoveryCard({
    super.key,
    required this.result,
    required this.source,
    this.store,
    this.onChanged,
    this.skipPrefsLoad = false,
    this.initialAction,
  });

  const NotRelevantRecoveryCard.test({
    super.key,
    required this.result,
    required this.source,
    this.store,
    this.onChanged,
    this.initialAction,
  })  : skipPrefsLoad = true;

  final NotRelevantRecoveryResult result;
  final String source;
  final NotRelevantRecoveryStore? store;
  final VoidCallback? onChanged;
  final bool skipPrefsLoad;
  final NotRelevantRecoveryActionType? initialAction;

  @override
  State<NotRelevantRecoveryCard> createState() =>
      _NotRelevantRecoveryCardState();
}

class _NotRelevantRecoveryCardState extends State<NotRelevantRecoveryCard> {
  NotRelevantRecoveryActionType? _selectedAction;
  var _trackedSeen = false;

  @override
  void initState() {
    super.initState();
    _selectedAction = widget.initialAction ??
        (widget.skipPrefsLoad
            ? null
            : NotRelevantRecoveryStore.recordFor(widget.result.proofKey)
                .actionType);
    if (!widget.skipPrefsLoad) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    await NotRelevantRecoveryStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _selectedAction ??=
          NotRelevantRecoveryStore.recordFor(widget.result.proofKey).actionType;
    });
  }

  void _trackSeenOnce() {
    if (_trackedSeen || _selectedAction != null) return;
    _trackedSeen = true;
    NotRelevantRecoveryAnalytics.seen(
      source: widget.source,
      result: widget.result,
    );
  }

  Future<void> _selectAction(NotRelevantRecoveryActionType actionType) async {
    if (_selectedAction != null) return;

    final store = widget.store ?? NotRelevantRecoveryStore.instance();
    await store.saveAction(
      proofKey: widget.result.proofKey,
      actionType: actionType,
      entryCount: widget.result.entryCount,
    );

    NotRelevantRecoveryAnalytics.actionTapped(
      source: widget.source,
      actionType: actionType,
      result: widget.result,
    );

    if (!mounted) return;
    setState(() => _selectedAction = actionType);
    widget.onChanged?.call();

    unawaited(
      NotRelevantRecoveryEngine.syncCorrectionFromAction(
        result: widget.result,
        actionType: actionType,
        source: widget.source,
      ),
    );
  }

  Key _actionKey(NotRelevantRecoveryActionType action) =>
      Key('not_relevant_recovery_${action.storageValue}');

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final answered = _selectedAction;

    if (answered != null) {
      return Container(
        key: const Key('not_relevant_recovery_answered_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration:
            VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
        child: Text(
          NotRelevantRecoveryCopy.followUpFor(answered),
          key: Key('not_relevant_recovery_follow_up_${answered.storageValue}'),
          style: bodyStyle.copyWith(color: AppColors.textPrimary),
        ),
      );
    }

    return Container(
      key: const Key('not_relevant_recovery_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('not_relevant_recovery_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('not_relevant_recovery_body'),
            style: bodyStyle,
          ),
          if (widget.result.hasFreshReturn) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.returnedAfterCorrectionLine,
              key: const Key('not_relevant_recovery_returned_after_correction'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.correctionLine,
            key: const Key('not_relevant_recovery_correction_line'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.returnLine,
            key: const Key('not_relevant_recovery_return_line'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final action in NotRelevantRecoveryActionType.values)
                TextButton(
                  key: _actionKey(action),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () => unawaited(_selectAction(action)),
                  child: Text(NotRelevantRecoveryCopy.actionLabel(action)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
