import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_analytics.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Optional post-save check — stronger, same, or softer than the last repeat.
class RepeatReturnCheckCard extends StatefulWidget {
  const RepeatReturnCheckCard({
    required this.entryId, required this.entryCount, required this.surface, super.key,
    this.store,
    this.skipPrefsLoad = false,
    this.initialRecord,
    this.onChanged,
  });

  const RepeatReturnCheckCard.test({
    required this.entryId, required this.entryCount, required this.surface, super.key,
    this.store,
    this.onChanged,
    this.initialRecord,
  }) : skipPrefsLoad = true;

  final String entryId;
  final int entryCount;
  final String surface;
  final RepeatReturnCheckStore? store;
  final bool skipPrefsLoad;
  final RepeatReturnCheckRecord? initialRecord;
  final VoidCallback? onChanged;

  @override
  State<RepeatReturnCheckCard> createState() => _RepeatReturnCheckCardState();
}

class _RepeatReturnCheckCardState extends State<RepeatReturnCheckCard> {
  RepeatReturnCheckStore? _store;
  RepeatReturnCheckRecord? _record;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _record = widget.initialRecord;
      _loading = false;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    _store ??= widget.store ?? RepeatReturnCheckStore.instance();
    final records = await _store!.loadAll();
    if (!mounted) return;
    setState(() {
      _record = records
          .where((item) => item.entryId == widget.entryId)
          .firstOrNull;
      _loading = false;
    });
  }

  Future<void> _refreshRecord() async {
    _store ??= widget.store ?? RepeatReturnCheckStore.instance();
    final records = await _store!.loadAll();
    if (!mounted) return;
    setState(() {
      _record = records
          .where((item) => item.entryId == widget.entryId)
          .firstOrNull;
    });
  }

  Future<void> _dismiss() async {
    _store ??= widget.store ?? RepeatReturnCheckStore.instance();
    RepeatReturnCheckAnalytics.recordDismissed(
      entryCount: widget.entryCount,
      surface: widget.surface,
    );
    await _store!.dismiss(
      entryId: widget.entryId,
      entryCountAtCapture: widget.entryCount,
    );
    if (!mounted) return;
    await _refreshRecord();
    widget.onChanged?.call();
  }

  Future<void> _select(RepeatReturnCheckChoice choice) async {
    _store ??= widget.store ?? RepeatReturnCheckStore.instance();
    RepeatReturnCheckAnalytics.recordChoice(
      choice: choice,
      entryCount: widget.entryCount,
      surface: widget.surface,
    );
    await _store!.saveChoice(
      entryId: widget.entryId,
      choice: choice,
      entryCountAtCapture: widget.entryCount,
    );
    if (!mounted) return;
    await _refreshRecord();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('repeat_return_check_loading'));
    }

    final record = _record;
    if (record != null && record.completed) {
      if (record.choice != null) {
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            RepeatReturnCheckCopy.saved,
            key: const Key('repeat_return_check_saved'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary, fontSize: 12),
          ),
        );
      }
      return const SizedBox.shrink(key: Key('repeat_return_check_hidden'));
    }

    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 13);

    return Container(
      key: const Key('repeat_return_check_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  RepeatReturnCheckCopy.prompt,
                  key: const Key('repeat_return_check_prompt'),
                  style: helperStyle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const Key('repeat_return_check_dismiss'),
                onPressed: _dismiss,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: RepeatReturnCheckCopy.dismiss,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final choice in RepeatReturnCheckChoice.legacyOfferChoices)
                OutlinedButton(
                  key: Key('repeat_return_check_${choice.name}'),
                  onPressed: () => _select(choice),
                  child: Text(choice.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}