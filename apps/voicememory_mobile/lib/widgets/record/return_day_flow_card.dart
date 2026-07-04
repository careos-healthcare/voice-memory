import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/return_day/return_day_flow_analytics.dart';
import '../../features/return_day/return_day_flow_copy.dart';
import '../../features/return_day/return_day_flow_model.dart';
import '../../features/return_day/return_day_flow_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Return Day Flow v2 — next-day return loop on record ready.
class ReturnDayFlowCard extends StatefulWidget {
  const ReturnDayFlowCard({
    super.key,
    required this.flow,
    required this.entryCount,
    this.store,
    this.skipPrefsLoad = false,
    this.initialAnswer,
    this.onAnswered,
    this.onCameBack,
    this.onDifferent,
  });

  const ReturnDayFlowCard.test({
    super.key,
    required this.flow,
    required this.entryCount,
    this.store,
    this.onAnswered,
    this.onCameBack,
    this.onDifferent,
    ReturnDayFlowAnswer? initialAnswer,
  })  : skipPrefsLoad = true,
        initialAnswer = initialAnswer;

  final ReturnDayFlow flow;
  final int entryCount;
  final ReturnDayFlowStore? store;
  final bool skipPrefsLoad;
  final ReturnDayFlowAnswer? initialAnswer;
  final VoidCallback? onAnswered;
  final VoidCallback? onCameBack;
  final VoidCallback? onDifferent;

  @override
  State<ReturnDayFlowCard> createState() => _ReturnDayFlowCardState();
}

class _ReturnDayFlowCardState extends State<ReturnDayFlowCard> {
  ReturnDayFlowStore? _store;
  ReturnDayFlowAnswer? _answer;
  bool _loading = true;
  bool _seenTracked = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _answer = widget.initialAnswer;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    await ReturnDayFlowStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _answer = ReturnDayFlowStore.todayAnswer;
      _loading = false;
    });
  }

  void _trackSeen() {
    if (_seenTracked || _answer != null) return;
    _seenTracked = true;
    ReturnDayFlowAnalytics.seen(
      source: 'record',
      entryCount: widget.entryCount,
      hasGroundedPhrase: widget.flow.hasGroundedPhrase,
    );
  }

  Future<void> _select(ReturnDayFlowAnswer answer) async {
    final answerKey = switch (answer) {
      ReturnDayFlowAnswer.cameBack => 'came_back',
      ReturnDayFlowAnswer.notToday => 'not_today',
      ReturnDayFlowAnswer.different => 'different',
    };
    ReturnDayFlowAnalytics.answered(
      source: 'record',
      entryCount: widget.entryCount,
      answer: answerKey,
      hasGroundedPhrase: widget.flow.hasGroundedPhrase,
    );
    if (!widget.skipPrefsLoad || widget.store != null) {
      _store ??= widget.store ?? ReturnDayFlowStore.instance();
      await _store!.saveTodayAnswer(answer);
    }
    if (!mounted) return;
    if (answer == ReturnDayFlowAnswer.cameBack) {
      widget.onCameBack?.call();
    } else if (answer == ReturnDayFlowAnswer.different) {
      widget.onDifferent?.call();
    }
    setState(() => _answer = answer);
    if (answer != ReturnDayFlowAnswer.notToday) {
      widget.onAnswered?.call();
    }
  }

  String? _helperFor(ReturnDayFlowAnswer answer) => switch (answer) {
        ReturnDayFlowAnswer.cameBack => ReturnDayFlowCopy.helperCameBack,
        ReturnDayFlowAnswer.notToday => ReturnDayFlowCopy.helperNotToday,
        ReturnDayFlowAnswer.different => ReturnDayFlowCopy.helperDifferent,
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('return_day_flow_loading'));
    }

    _trackSeen();

    final helper = _answer != null ? _helperFor(_answer!) : null;
    final showChoices = _answer == null;
    final notTodayAck = _answer == ReturnDayFlowAnswer.notToday;

    return Container(
      key: const Key('return_day_flow_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7FAF6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!notTodayAck) ...[
            Text(
              widget.flow.title,
              key: const Key('return_day_flow_title'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.flow.body,
              key: const Key('return_day_flow_body'),
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (showChoices) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              key: const Key('return_day_flow_yes'),
              onPressed: () => _select(ReturnDayFlowAnswer.cameBack),
              child: const Text(ReturnDayFlowCopy.yesCameBack),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('return_day_flow_not_today'),
              onPressed: () => _select(ReturnDayFlowAnswer.notToday),
              child: const Text(ReturnDayFlowCopy.notToday),
            ),
            TextButton(
              key: const Key('return_day_flow_different'),
              onPressed: () => _select(ReturnDayFlowAnswer.different),
              child: const Text(ReturnDayFlowCopy.different),
            ),
          ] else if (helper != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              helper,
              key: Key('return_day_flow_helper_${_answer!.name}'),
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
