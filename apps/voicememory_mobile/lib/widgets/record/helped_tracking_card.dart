import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/helped_tracking/helped_tracking_analytics.dart';
import '../../features/helped_tracking/helped_tracking_copy.dart';
import '../../features/helped_tracking/helped_tracking_model.dart';
import '../../features/helped_tracking/helped_tracking_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'helped_tracking_sheet.dart';

/// Post-save helped tracking question — user-reported evidence only.
class HelpedTrackingCard extends StatefulWidget {
  const HelpedTrackingCard({
    super.key,
    required this.prompt,
    required this.source,
    this.store,
    this.skipPrefsLoad = false,
    this.onChanged,
  });

  const HelpedTrackingCard.test({
    super.key,
    required this.prompt,
    required this.source,
    this.store,
    this.onChanged,
  })  : skipPrefsLoad = true;

  final HelpedTrackingPrompt prompt;
  final String source;
  final HelpedTrackingStore? store;
  final bool skipPrefsLoad;
  final VoidCallback? onChanged;

  @override
  State<HelpedTrackingCard> createState() => _HelpedTrackingCardState();
}

class _HelpedTrackingCardState extends State<HelpedTrackingCard> {
  HelpedTrackingStore? _store;
  bool _saving = false;
  bool _answered = false;
  String? _statusMessage;
  var _trackedSeen = false;

  HelpedTrackingStore get _resolvedStore =>
      _store ??= widget.store ?? HelpedTrackingStore.instance();

  bool get _hasStoredAnswer =>
      HelpedTrackingStore.cached
          .any((record) => record.entryId == widget.prompt.entryId);

  @override
  void initState() {
    super.initState();
    _answered = _hasStoredAnswer;
  }

  void _trackSeenOnce() {
    if (_trackedSeen || _answered || _hasStoredAnswer) return;
    _trackedSeen = true;
    HelpedTrackingAnalytics.promptSeen(
      source: widget.source,
      entryCount: widget.prompt.entryCount,
    );
  }

  Future<void> _select(HelpedTrackingOption option) async {
    if (_saving || _answered || _hasStoredAnswer) return;

    if (option == HelpedTrackingOption.somethingElse) {
      final saved = await HelpedTrackingSheet.show(
        context,
        onSave: (text) async {
          await _resolvedStore.saveSelection(
            entryId: widget.prompt.entryId,
            option: option,
            entryCountAtCapture: widget.prompt.entryCount,
            freeText: text,
          );
        },
      );
      if (!mounted || saved != true) return;
      HelpedTrackingAnalytics.optionSelected(
        source: widget.source,
        entryCount: widget.prompt.entryCount,
        option: option,
        hasFreeText: true,
      );
      setState(() {
        _answered = true;
        _statusMessage = HelpedTrackingCopy.savedMessage;
      });
      widget.onChanged?.call();
      return;
    }

    _saving = true;
    unawaited(
      _resolvedStore.saveSelection(
        entryId: widget.prompt.entryId,
        option: option,
        entryCountAtCapture: widget.prompt.entryCount,
      ),
    );
    HelpedTrackingAnalytics.optionSelected(
      source: widget.source,
      entryCount: widget.prompt.entryCount,
      option: option,
      hasFreeText: false,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _answered = true;
      _statusMessage = HelpedTrackingCopy.savedMessage;
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    if (_statusMessage != null) {
      return Container(
        key: const Key('helped_tracking_saved_message'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
        child: Text(
          _statusMessage!,
          style: bodyStyle.copyWith(color: AppColors.textPrimary),
        ),
      );
    }

    if (_answered || _hasStoredAnswer) {
      return const SizedBox.shrink(key: Key('helped_tracking_hidden'));
    }

    return Container(
      key: const Key('helped_tracking_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            HelpedTrackingCopy.question,
            key: const Key('helped_tracking_question'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in widget.prompt.options)
                OutlinedButton(
                  key: Key('helped_tracking_option_${option.name}'),
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
