import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/entry_importance/entry_importance_analytics.dart';
import '../../features/entry_importance/entry_importance_copy.dart';
import '../../features/entry_importance/entry_importance_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Toggle for marking one saved moment as important.
class EntryImportanceButton extends StatefulWidget {
  const EntryImportanceButton({
    super.key,
    required this.entryId,
    required this.source,
    required this.entryCount,
    this.onChanged,
    this.compact = false,
  });

  final String entryId;
  final String source;
  final int entryCount;
  final VoidCallback? onChanged;
  final bool compact;

  @override
  State<EntryImportanceButton> createState() => _EntryImportanceButtonState();
}

class _EntryImportanceButtonState extends State<EntryImportanceButton> {
  bool _busy = false;

  bool get _isImportant => EntryImportanceStore.isImportant(widget.entryId);

  Future<void> _mark() async {
    if (_busy) return;
    setState(() => _busy = true);
    await EntryImportanceStore.instance().mark(widget.entryId);
    EntryImportanceAnalytics.marked(
      source: widget.source,
      entryCount: widget.entryCount,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(EntryImportanceCopy.markedSuccess)),
    );
  }

  Future<void> _unmark() async {
    if (_busy) return;
    setState(() => _busy = true);
    await EntryImportanceStore.instance().unmark(widget.entryId);
    EntryImportanceAnalytics.removed(
      source: widget.source,
      entryCount: widget.entryCount,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final chipStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.accentPrimary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    if (_isImportant) {
      return Wrap(
        key: Key('entry_importance_marked_${widget.entryId}'),
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          Container(
            key: Key('entry_importance_chip_${widget.entryId}'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              EntryImportanceCopy.importantLabel,
              style: chipStyle,
            ),
          ),
          TextButton(
            key: Key('entry_importance_remove_${widget.entryId}'),
            onPressed: _busy ? null : () => unawaited(_unmark()),
            child: Text(
              widget.compact
                  ? EntryImportanceCopy.removeImportant
                  : EntryImportanceCopy.removeImportant,
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: Key('entry_importance_mark_${widget.entryId}'),
        onPressed: _busy ? null : () => unawaited(_mark()),
        child: const Text(EntryImportanceCopy.markImportant),
      ),
    );
  }
}
