import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/what_changed/what_changed_v2_analytics.dart';
import '../../features/what_changed/what_changed_v2_copy.dart';
import '../../features/what_changed/what_changed_v2_model.dart';
import '../../features/what_changed/what_changed_v2_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Post-save What Changed v2 question — replaces legacy return-check answer UI.
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
  bool _answered = false;
  String? _statusMessage;
  var _trackedSeen = false;

  WhatChangedV2Store get _resolvedStore =>
      _store ??= widget.store ?? WhatChangedV2Store.instance();

  bool get _hasStoredAnswer =>
      WhatChangedV2Store.cached
          .any((record) => record.entryId == widget.prompt.entryId);

  void _trackSeenOnce() {
    if (_trackedSeen || _answered || _hasStoredAnswer) return;
    _trackedSeen = true;
    WhatChangedV2Analytics.seen(
      source: widget.source,
      entryCount: widget.prompt.entryCount,
      hasConfirmedRepeat: widget.prompt.hasConfirmedRepeat,
    );
  }

  Future<void> _select(WhatChangedV2Option option) async {
    if (_saving || _answered || _hasStoredAnswer) return;
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
      _answered = true;
      _statusMessage = WhatChangedV2Copy.savedMessage(option);
    });
    widget.onChanged?.call();
    if (option == WhatChangedV2Option.somethingHelped) {
      widget.onSomethingHelped?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.4,
    );

    if (_statusMessage != null) {
      return Container(
        key: const Key('what_changed_v2_saved_message'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
        child: Text(
          _statusMessage!,
          style: bodyStyle,
        ),
      );
    }

    if (_answered || _hasStoredAnswer) {
      return const SizedBox.shrink(key: Key('what_changed_v2_hidden'));
    }

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
