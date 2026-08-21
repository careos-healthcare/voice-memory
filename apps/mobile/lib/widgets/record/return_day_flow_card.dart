import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import 'package:archiveme_mobile/features/return_day/return_day_flow_model.dart';
import 'package:archiveme_mobile/features/return_day/return_day_flow_store.dart';
import 'package:archiveme_mobile/widgets/record/return_watch_question_card.dart';
import 'package:flutter/material.dart';

/// Return Day Flow v2 — next-day return loop on record ready.
class ReturnDayFlowCard extends StatelessWidget {
  const ReturnDayFlowCard({
    required this.flow, required this.entryCount, super.key,
    this.store,
    this.skipPrefsLoad = false,
    this.initialAnswer,
    this.onAnswered,
    this.onCameBack,
    this.onDifferent,
  });

  const ReturnDayFlowCard.test({
    required this.flow, required this.entryCount, super.key,
    this.store,
    this.onAnswered,
    this.onCameBack,
    this.onDifferent,
    this.initialAnswer,
  }) : skipPrefsLoad = true;

  final ReturnDayFlow flow;
  final int entryCount;
  final ReturnDayFlowStore? store;
  final bool skipPrefsLoad;
  final ReturnDayFlowAnswer? initialAnswer;
  final VoidCallback? onAnswered;
  final VoidCallback? onCameBack;
  final VoidCallback? onDifferent;

  ComeBackTomorrowReturnQuestion get _question =>
      ComeBackTomorrowReturnQuestion(
        title: flow.title,
        body: flow.body,
        groundedPhrase: flow.watchingPhrase ?? '',
        daysSinceSet: flow.daysSinceSet,
        source: flow.source,
      );

  ComeBackTomorrowAnswerType? get _initialAnswer => switch (initialAnswer) {
    ReturnDayFlowAnswer.cameBack => ComeBackTomorrowAnswerType.cameBack,
    ReturnDayFlowAnswer.notToday => ComeBackTomorrowAnswerType.notToday,
    ReturnDayFlowAnswer.different => ComeBackTomorrowAnswerType.different,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    return ReturnWatchQuestionCard(
      key: const Key('return_day_flow_card'),
      question: _question,
      entryCount: entryCount,
      returnDayStore: store,
      skipPrefsLoad: skipPrefsLoad,
      initialAnswer: _initialAnswer,
      onAnswered: onAnswered,
      onCameBack: onCameBack,
      onDifferent: onDifferent,
    );
  }
}