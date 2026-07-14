import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/what_changed/what_changed_v2_analytics.dart';
import '../../features/beta_improvement/proof_emotional_clarity_engine.dart';
import '../../features/what_changed/what_changed_v2_copy.dart';
import '../../features/what_changed/what_changed_v2_model.dart';
import '../../features/what_changed/what_changed_v2_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Post-save What Changed v3 — last time vs this time comparison.
class WhatChangedV2Card extends StatefulWidget {
  const WhatChangedV2Card({
    super.key,
    required this.prompt,
    required this.source,
    this.store,
    this.onSomethingHelped,
    this.onChanged,
  });

  const WhatChangedV2Card.test({
    super.key,
    required this.prompt,
    required this.source,
    this.store,
    this.onSomethingHelped,
    this.onChanged,
  });

  final WhatChangedV2Prompt prompt;
  final String source;
  final WhatChangedV2Store? store;
  final VoidCallback? onSomethingHelped;
  final VoidCallback? onChanged;

  @override
  State<WhatChangedV2Card> createState() => _WhatChangedV2CardState();
}

class _WhatChangedV2CardState extends State<WhatChangedV2Card> {
  WhatChangedV2Store? _store;
  bool _saving = false;
  WhatChangedV2Option? _selectedOption;
  var _trackedSeen = false;

  WhatChangedV2Store get _resolvedStore =>
      _store ??= widget.store ?? WhatChangedV2Store.instance();

  WhatChangedV2Record? get _storedRecord {
    for (final record in WhatChangedV2Store.cached) {
      if (record.entryId == widget.prompt.entryId) return record;
    }
    return null;
  }

  WhatChangedV2Option? get _answeredOption =>
      _selectedOption ?? _storedRecord?.option;

  void _trackSeenOnce() {
    if (_trackedSeen || _answeredOption != null) return;
    _trackedSeen = true;
    WhatChangedV2Analytics.seen(
      source: widget.source,
      entryCount: widget.prompt.entryCount,
      hasConfirmedRepeat: widget.prompt.hasConfirmedRepeat,
    );
  }

  Future<void> _select(WhatChangedV2Option option) async {
    if (_saving || _answeredOption != null) return;
    _saving = true;
    unawaited(
      _resolvedStore.saveSelection(
        entryId: widget.prompt.entryId,
        option: option,
        entryCountAtCapture: widget.prompt.entryCount,
      ),
    );
    WhatChangedV2Analytics.answered(
      source: widget.source,
      entryCount: widget.prompt.entryCount,
      answer: option,
      hasConfirmedRepeat: widget.prompt.hasConfirmedRepeat,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _selectedOption = option;
    });
    widget.onChanged?.call();
    if (option == WhatChangedV2Option.somethingHelped) {
      widget.onSomethingHelped?.call();
    }
  }

  Widget _buildPayoffCard(BuildContext context, WhatChangedV2Option option) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final comparison = widget.prompt.comparison;
    final emotionalHeadline = ProofEmotionalClarityEngine.payoffHeadlineForWhatChanged(
      entryCount: widget.prompt.entryCount,
      option: option,
    );

    return Container(
      key: const Key('what_changed_v2_payoff_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (emotionalHeadline != null) ...[
            Text(
              emotionalHeadline,
              key: const Key('what_changed_v2_emotional_headline'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            WhatChangedV2Copy.payoffMessage(option),
            key: const Key('what_changed_v2_payoff_line'),
            style: bodyStyle,
          ),
          if (comparison != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              WhatChangedV2Copy.thenLabel,
              key: const Key('what_changed_v2_then_label'),
              style: labelStyle,
            ),
            const SizedBox(height: 2),
            Text(
              WhatChangedV2Copy.formatSnippet(comparison.thenSnippet),
              key: const Key('what_changed_v2_then_snippet'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              WhatChangedV2Copy.nowLabel,
              key: const Key('what_changed_v2_now_label'),
              style: labelStyle,
            ),
            const SizedBox(height: 2),
            Text(
              WhatChangedV2Copy.formatSnippet(comparison.nowSnippet),
              key: const Key('what_changed_v2_now_snippet'),
              style: bodyStyle,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final answered = _answeredOption;
    if (answered != null) {
      return _buildPayoffCard(context, answered);
    }

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('what_changed_v2_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            WhatChangedV2Copy.question,
            key: const Key('what_changed_v2_question'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            WhatChangedV2Copy.body,
            key: const Key('what_changed_v2_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in widget.prompt.options)
                OutlinedButton(
                  key: Key('what_changed_v2_option_${option.name}'),
                  onPressed: _saving ? null : () => _select(option),
                  child: Text(option.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
