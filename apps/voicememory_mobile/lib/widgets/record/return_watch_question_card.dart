import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/come_back_tomorrow/come_back_tomorrow_v2_analytics.dart';
import '../../features/come_back_tomorrow/come_back_tomorrow_v2_copy.dart';
import '../../features/come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import '../../features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import '../../features/return_day/return_day_flow_model.dart';
import '../../features/return_day/return_day_flow_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Return-day watch question — v2 copy with grounded phrase line.
class ReturnWatchQuestionCard extends StatefulWidget {
  const ReturnWatchQuestionCard({
    super.key,
    required this.question,
    required this.entryCount,
    this.store,
    this.returnDayStore,
    this.skipPrefsLoad = false,
    this.initialAnswer,
    this.onAnswered,
    this.onCameBack,
    this.onDifferent,
  });

  const ReturnWatchQuestionCard.test({
    super.key,
    required this.question,
    required this.entryCount,
    this.store,
    this.returnDayStore,
    this.onAnswered,
    this.onCameBack,
    this.onDifferent,
    ComeBackTomorrowAnswerType? initialAnswer,
  })  : skipPrefsLoad = true,
        initialAnswer = initialAnswer;

  final ComeBackTomorrowReturnQuestion question;
  final int entryCount;
  final ComeBackTomorrowV2Store? store;
  final ReturnDayFlowStore? returnDayStore;
  final bool skipPrefsLoad;
  final ComeBackTomorrowAnswerType? initialAnswer;
  final VoidCallback? onAnswered;
  final VoidCallback? onCameBack;
  final VoidCallback? onDifferent;

  @override
  State<ReturnWatchQuestionCard> createState() => _ReturnWatchQuestionCardState();
}

class _ReturnWatchQuestionCardState extends State<ReturnWatchQuestionCard> {
  ComeBackTomorrowV2Store? _store;
  ReturnDayFlowStore? _returnDayStore;
  ComeBackTomorrowAnswerType? _answer;
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
      final stored = ReturnDayFlowStore.todayAnswer;
      _answer = switch (stored) {
        ReturnDayFlowAnswer.cameBack => ComeBackTomorrowAnswerType.cameBack,
        ReturnDayFlowAnswer.notToday => ComeBackTomorrowAnswerType.notToday,
        ReturnDayFlowAnswer.different => ComeBackTomorrowAnswerType.different,
        null => null,
      };
      _loading = false;
    });
  }

  void _trackSeen() {
    if (_seenTracked || _answer != null) return;
    _seenTracked = true;
    ComeBackTomorrowV2Analytics.questionSeen(
      source: widget.question.source,
      entryCount: widget.entryCount,
      daysSinceSet: widget.question.daysSinceSet,
    );
  }

  Future<void> _select(ComeBackTomorrowAnswerType answer) async {
    final answerKey = switch (answer) {
      ComeBackTomorrowAnswerType.cameBack => 'came_back',
      ComeBackTomorrowAnswerType.notToday => 'not_today',
      ComeBackTomorrowAnswerType.different => 'different',
    };
    ComeBackTomorrowV2Analytics.answered(
      source: widget.question.source,
      entryCount: widget.entryCount,
      answerType: answerKey,
    );
    if (widget.store != null) {
      await widget.store!.recordAnswer(answer: answer);
    } else if (!widget.skipPrefsLoad) {
      _store ??= ComeBackTomorrowV2Store.instance();
      await _store!.recordAnswer(answer: answer);
    }
    final returnAnswer = switch (answer) {
      ComeBackTomorrowAnswerType.cameBack => ReturnDayFlowAnswer.cameBack,
      ComeBackTomorrowAnswerType.notToday => ReturnDayFlowAnswer.notToday,
      ComeBackTomorrowAnswerType.different => ReturnDayFlowAnswer.different,
    };
    if (widget.returnDayStore != null) {
      await widget.returnDayStore!.saveTodayAnswer(returnAnswer);
    } else if (!widget.skipPrefsLoad) {
      _returnDayStore ??= ReturnDayFlowStore.instance();
      await _returnDayStore!.saveTodayAnswer(returnAnswer);
    }
    if (!mounted) return;
    if (answer == ComeBackTomorrowAnswerType.cameBack) {
      widget.onCameBack?.call();
    } else if (answer == ComeBackTomorrowAnswerType.different) {
      widget.onDifferent?.call();
    }
    setState(() => _answer = answer);
    if (answer != ComeBackTomorrowAnswerType.notToday) {
      widget.onAnswered?.call();
    }
  }

  String? _helperFor(ComeBackTomorrowAnswerType answer) => switch (answer) {
        ComeBackTomorrowAnswerType.cameBack =>
          ComeBackTomorrowV2Copy.helperCameBack,
        ComeBackTomorrowAnswerType.notToday =>
          ComeBackTomorrowV2Copy.helperNotToday,
        ComeBackTomorrowAnswerType.different =>
          ComeBackTomorrowV2Copy.helperDifferent,
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('return_watch_question_loading'));
    }

    _trackSeen();

    final helper = _answer != null ? _helperFor(_answer!) : null;
    final showChoices = _answer == null;
    final notTodayAck = _answer == ComeBackTomorrowAnswerType.notToday;
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
    );
    final phraseStyle = bodyStyle.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return Container(
      key: const Key('return_watch_question_card'),
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
              widget.question.title,
              key: const Key('return_watch_question_title'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.question.body,
              key: const Key('return_watch_question_body'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ComeBackTomorrowV2Copy.quotedPhrase(widget.question.groundedPhrase),
              key: const Key('return_watch_question_phrase'),
              style: phraseStyle,
            ),
          ],
          if (showChoices) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              key: const Key('return_watch_question_yes'),
              onPressed: () => _select(ComeBackTomorrowAnswerType.cameBack),
              child: const Text(ComeBackTomorrowV2Copy.yesCameBack),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('return_watch_question_not_today'),
              onPressed: () => _select(ComeBackTomorrowAnswerType.notToday),
              child: const Text(ComeBackTomorrowV2Copy.notToday),
            ),
            TextButton(
              key: const Key('return_watch_question_different'),
              onPressed: () => _select(ComeBackTomorrowAnswerType.different),
              child: const Text(ComeBackTomorrowV2Copy.different),
            ),
          ] else if (helper != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              helper,
              key: Key('return_watch_question_helper_${_answer!.name}'),
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
