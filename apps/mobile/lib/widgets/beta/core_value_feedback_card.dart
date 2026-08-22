import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta/core_value_feedback_analytics.dart';
import 'package:archiveme_mobile/features/beta/core_value_feedback_copy.dart';
import 'package:archiveme_mobile/features/beta/core_value_feedback_model.dart';
import 'package:archiveme_mobile/features/beta/core_value_feedback_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Beta-only core value feedback — small, calm, never blocks proof payoff.
class CoreValueFeedbackCard extends StatefulWidget {
  const CoreValueFeedbackCard({
    required this.source, required this.entryCount, required this.hasConfirmedRepeat, required this.hasFirstProof, super.key,
    this.onChanged,
    this.store,
    this.skipPrefsLoad = false,
    this.initialDismissed = false,
    this.initialRecord,
  });

  const CoreValueFeedbackCard.test({
    required this.source, required this.entryCount, required this.hasConfirmedRepeat, required this.hasFirstProof, super.key,
    this.onChanged,
    this.store,
    bool dismissed = false,
    this.initialRecord,
  }) : skipPrefsLoad = true,
       initialDismissed = dismissed;

  final CoreValueFeedbackSource source;
  final int entryCount;
  final bool hasConfirmedRepeat;
  final bool hasFirstProof;
  final VoidCallback? onChanged;
  final CoreValueFeedbackStore? store;
  final bool skipPrefsLoad;
  final bool initialDismissed;
  final CoreValueFeedbackRecord? initialRecord;

  @override
  State<CoreValueFeedbackCard> createState() => _CoreValueFeedbackCardState();
}

class _CoreValueFeedbackCardState extends State<CoreValueFeedbackCard> {
  CoreValueFeedbackStore? _store;
  bool _dismissed = false;
  bool _answered = false;
  bool _seenLogged = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _dismissed = widget.initialDismissed;
      _answered = widget.initialRecord?.answered ?? false;
      return;
    }
    _dismissed = CoreValueFeedbackStore.isDismissed;
    _answered = CoreValueFeedbackStore.cached.answered;
    unawaited(_load());
  }

  Future<void> _load() async {
    await CoreValueFeedbackStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _dismissed = CoreValueFeedbackStore.isDismissed;
      _answered = CoreValueFeedbackStore.cached.answered;
    });
  }

  void _logSeenIfNeeded() {
    if (_seenLogged || _dismissed || _answered) return;
    _seenLogged = true;
    CoreValueFeedbackAnalytics.seen(
      entryCount: widget.entryCount,
      source: widget.source,
      hasConfirmedRepeat: widget.hasConfirmedRepeat,
      hasFirstProof: widget.hasFirstProof,
    );
  }

  Future<void> _hideForNow() async {
    _store ??= widget.store ?? CoreValueFeedbackStore.instance();
    setState(() => _dismissed = true);
    _store!.dismissForSession();
    CoreValueFeedbackAnalytics.dismissed(
      entryCount: widget.entryCount,
      source: widget.source,
      hasConfirmedRepeat: widget.hasConfirmedRepeat,
      hasFirstProof: widget.hasFirstProof,
    );
    if (!mounted) return;
    widget.onChanged?.call();
  }

  Future<void> _selectAnswer(CoreValueFeedbackAnswer answer) async {
    _store ??= widget.store ?? CoreValueFeedbackStore.instance();
    await _store!.saveAnswer(
      answer: answer,
      entryCount: widget.entryCount,
      source: widget.source,
    );
    CoreValueFeedbackAnalytics.answered(
      answer: answer,
      entryCount: widget.entryCount,
      source: widget.source,
      hasConfirmedRepeat: widget.hasConfirmedRepeat,
      hasFirstProof: widget.hasFirstProof,
    );
    if (!mounted) return;
    setState(() => _answered = true);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink(key: Key('core_value_feedback_hidden'));
    }

    if (_answered) {
      return Container(
        key: const Key('core_value_feedback_saved'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
        child: Text(
          CoreValueFeedbackCopy.savedMessage,
          key: const Key('core_value_feedback_saved_message'),
          style: ArchiveMobileTypography.listSubtitle(
            context,
          ).copyWith(height: 1.45),
        ),
      );
    }

    _logSeenIfNeeded();

    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    return Container(
      key: const Key('core_value_feedback_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            CoreValueFeedbackCopy.title,
            key: const Key('core_value_feedback_title'),
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CoreValueFeedbackCopy.question,
            key: const Key('core_value_feedback_question'),
            style: ArchiveMobileTypography.listSubtitle(
              context,
            ).copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CoreValueFeedbackCopy.helper,
            key: const Key('core_value_feedback_helper'),
            style: helperStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(
                key: const Key('core_value_feedback_yes'),
                onPressed: () =>
                    unawaited(_selectAnswer(CoreValueFeedbackAnswer.yes)),
                child: const Text(CoreValueFeedbackCopy.answerYes),
              ),
              TextButton(
                key: const Key('core_value_feedback_not_yet'),
                onPressed: () =>
                    unawaited(_selectAnswer(CoreValueFeedbackAnswer.notYet)),
                child: const Text(CoreValueFeedbackCopy.answerNotYet),
              ),
              TextButton(
                key: const Key('core_value_feedback_generic'),
                onPressed: () =>
                    unawaited(_selectAnswer(CoreValueFeedbackAnswer.generic)),
                child: const Text(CoreValueFeedbackCopy.answerGeneric),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('core_value_feedback_hide_for_now'),
              onPressed: _hideForNow,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text(CoreValueFeedbackCopy.hideForNow),
            ),
          ),
        ],
      ),
    );
  }
}