import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/correction_memory/correction_memory_engine.dart';
import '../../features/current_relevance/current_relevance_analytics.dart';
import '../../features/current_relevance/current_relevance_copy.dart';
import '../../features/current_relevance/current_relevance_engine.dart';
import '../../features/current_relevance/current_relevance_model.dart';
import '../../features/current_relevance/current_relevance_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Current relevance bridge — lets users correct what still matters today.
class CurrentRelevanceCard extends StatefulWidget {
  const CurrentRelevanceCard({
    super.key,
    required this.state,
    required this.source,
    this.store,
    this.onChanged,
  });

  const CurrentRelevanceCard.test({
    super.key,
    required this.state,
    required this.source,
    this.store,
    this.onChanged,
  });

  final CurrentRelevanceState state;
  final String source;
  final CurrentRelevanceStore? store;
  final VoidCallback? onChanged;

  @override
  State<CurrentRelevanceCard> createState() => _CurrentRelevanceCardState();
}

class _CurrentRelevanceCardState extends State<CurrentRelevanceCard> {
  CurrentRelevanceStore? _store;
  bool _saving = false;
  CurrentRelevanceAnswer? _selectedAnswer;
  var _trackedSeen = false;

  CurrentRelevanceStore get _resolvedStore =>
      _store ??= widget.store ?? CurrentRelevanceStore.instance();

  CurrentRelevanceAnswer? get _answeredAnswer =>
      _selectedAnswer ??
      widget.state.answer ??
      CurrentRelevanceStore.answerFor(widget.state.proofKey);

  void _trackSeenOnce() {
    if (_trackedSeen || _answeredAnswer != null) return;
    _trackedSeen = true;
    CurrentRelevanceAnalytics.seen(
      source: widget.source,
      entryCount: widget.state.entryCount,
      hasConfirmedRepeat: widget.state.hasConfirmedRepeat,
    );
  }

  Future<void> _select(CurrentRelevanceAnswer answer) async {
    if (_saving || _answeredAnswer != null) return;
    setState(() => _saving = true);
    await _resolvedStore.saveSelection(
      proofKey: widget.state.proofKey,
      answer: answer,
      entryCountAtCapture: widget.state.entryCount,
    );
    await CorrectionMemoryEngine.saveFromAnswer(
      proofKey: widget.state.proofKey,
      answer: answer,
      entryCountAtCapture: widget.state.entryCount,
      hasConfirmedRepeat: widget.state.hasConfirmedRepeat,
      source: widget.source,
    );
    CurrentRelevanceAnalytics.answered(
      source: widget.source,
      entryCount: widget.state.entryCount,
      answer: answer,
      hasConfirmedRepeat: widget.state.hasConfirmedRepeat,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _selectedAnswer = answer;
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final answered = _answeredAnswer;

    if (answered != null) {
      return Container(
        key: const Key('current_relevance_response_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: const Color(0xFFF8FAF8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              CurrentRelevanceCopy.responseFor(answered),
              key: Key('current_relevance_response_${answered.name}'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              CurrentRelevanceCopy.differentiationLine,
              key: const Key('current_relevance_differentiation_line'),
              style: ArchiveMobileTypography.cardLabel(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('current_relevance_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7FAF6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            CurrentRelevanceCopy.title,
            key: const Key('current_relevance_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CurrentRelevanceCopy.body,
            key: const Key('current_relevance_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final answer in CurrentRelevanceEngine.answerOptions)
                OutlinedButton(
                  key: Key('current_relevance_option_${answer.name}'),
                  onPressed: _saving ? null : () => _select(answer),
                  child: Text(CurrentRelevanceCopy.optionLabel(answer)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
