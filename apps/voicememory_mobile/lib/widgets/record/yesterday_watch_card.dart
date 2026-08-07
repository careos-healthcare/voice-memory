import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/retention/yesterday_watch_copy.dart';
import '../../features/retention/yesterday_watch_model.dart';
import '../../features/retention/yesterday_watch_store.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Next-day return loop — reminds what ArchiveMe was watching yesterday.
class YesterdayWatchCard extends StatefulWidget {
  const YesterdayWatchCard({
    super.key,
    required this.watch,
    required this.entryCount,
    this.store,
    this.skipPrefsLoad = false,
    this.initialAnswer,
    this.onAnswered,
    this.onCameBack,
    this.onDifferent,
  });

  const YesterdayWatchCard.test({
    super.key,
    required this.watch,
    required this.entryCount,
    this.store,
    this.onAnswered,
    this.onCameBack,
    this.onDifferent,
    this.initialAnswer,
  }) : skipPrefsLoad = true;

  final YesterdayWatch watch;
  final int entryCount;
  final YesterdayWatchStore? store;
  final bool skipPrefsLoad;
  final YesterdayWatchAnswer? initialAnswer;
  final VoidCallback? onAnswered;
  final VoidCallback? onCameBack;
  final VoidCallback? onDifferent;

  @override
  State<YesterdayWatchCard> createState() => _YesterdayWatchCardState();
}

class _YesterdayWatchCardState extends State<YesterdayWatchCard> {
  YesterdayWatchStore? _store;
  YesterdayWatchAnswer? _answer;
  bool _loading = true;

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
    await YesterdayWatchStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _answer = YesterdayWatchStore.todayAnswer;
      _loading = false;
    });
  }

  String get _daysStage {
    final days = widget.watch.daysSinceLastEntry;
    if (days <= 1) return 'day_1';
    if (days == 2) return 'day_2';
    return 'day_3_plus';
  }

  void _trackSeen() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.yesterdayWatchSeen,
      entryCount: widget.entryCount,
      source: 'record',
      stage: _daysStage,
      hasPhrase: widget.watch.hasGroundedPhrase,
      oncePerSession: true,
    );
  }

  Future<void> _select(YesterdayWatchAnswer answer) async {
    final answerKey = switch (answer) {
      YesterdayWatchAnswer.cameBack => 'came_back',
      YesterdayWatchAnswer.notToday => 'not_today',
      YesterdayWatchAnswer.different => 'different',
    };
    ActivationFunnelAnalytics.track(
      answer == YesterdayWatchAnswer.notToday
          ? ActivationFunnelAnalytics.yesterdayWatchDismissed
          : ActivationFunnelAnalytics.yesterdayWatchAnswered,
      entryCount: widget.entryCount,
      source: 'record',
      stage: _daysStage,
      answer: answerKey,
      hasPhrase: widget.watch.hasGroundedPhrase,
    );
    if (!widget.skipPrefsLoad || widget.store != null) {
      _store ??= widget.store ?? YesterdayWatchStore.instance();
      await _store!.saveTodayAnswer(answer);
    }
    if (!mounted) return;
    if (answer == YesterdayWatchAnswer.cameBack) {
      widget.onCameBack?.call();
    } else if (answer == YesterdayWatchAnswer.different) {
      widget.onDifferent?.call();
    }
    setState(() => _answer = answer);
    widget.onAnswered?.call();
  }

  String? _helperFor(YesterdayWatchAnswer answer) => switch (answer) {
    YesterdayWatchAnswer.cameBack => YesterdayWatchCopy.helperCameBack,
    YesterdayWatchAnswer.notToday => YesterdayWatchCopy.helperNotToday,
    YesterdayWatchAnswer.different => YesterdayWatchCopy.helperDifferent,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('yesterday_watch_loading'));
    }

    if (_answer == YesterdayWatchAnswer.notToday) {
      return const SizedBox.shrink(key: Key('yesterday_watch_hidden'));
    }

    _trackSeen();

    final helper = _answer != null ? _helperFor(_answer!) : null;
    final showChoices = _answer == null;

    return Container(
      key: const Key('yesterday_watch_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7FAF6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.watch.title,
            key: const Key('yesterday_watch_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.watch.body,
            key: const Key('yesterday_watch_body'),
            style: ArchiveMobileTypography.explanationBody(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          if (showChoices) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              key: const Key('yesterday_watch_yes'),
              onPressed: () => _select(YesterdayWatchAnswer.cameBack),
              child: const Text(YesterdayWatchCopy.yesCameBack),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('yesterday_watch_not_today'),
              onPressed: () => _select(YesterdayWatchAnswer.notToday),
              child: const Text(YesterdayWatchCopy.notToday),
            ),
            TextButton(
              key: const Key('yesterday_watch_different'),
              onPressed: () => _select(YesterdayWatchAnswer.different),
              child: const Text(YesterdayWatchCopy.different),
            ),
          ] else if (helper != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              helper,
              key: Key('yesterday_watch_helper_${_answer!.name}'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
