import 'package:flutter/material.dart';

import '../../features/action_items/action_item_store.dart';
import '../../features/action_items/archive_action_item.dart';
import '../../features/timeline/timeline_entry_display.dart';
import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import 'action_item_editor_sheet.dart';

/// Opens the action-item editor for one entry. Creates nothing until the
/// user saves — no auto-extraction from reflections or summaries.
class RememberThisButton extends StatefulWidget {
  const RememberThisButton({
    super.key,
    required this.entry,
    required this.store,
    this.source = 'entry_detail',
    this.compact = false,
    this.onSaved,
  });

  final JournalEntry entry;
  final ActionItemStore store;
  final String source;
  final bool compact;
  final VoidCallback? onSaved;

  @override
  State<RememberThisButton> createState() => _RememberThisButtonState();
}

class _RememberThisButtonState extends State<RememberThisButton> {
  ArchiveActionItem? _openItem;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final open = await widget.store.openItemForEntry(widget.entry.id);
    if (!mounted) return;
    setState(() {
      _openItem = open;
      _loading = false;
    });
  }

  Future<void> _tap() async {
    if (_busy || _loading) return;
    if (_openItem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ActionItemsCopy.alreadyRemembered),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.rememberThisTapped,
      source: widget.source,
    );
    setState(() => _busy = true);
    try {
      final saved = await showActionItemEditorSheet(
        context,
        store: widget.store,
        entry: widget.entry,
        prefillTitle: timelineEntryTitle(widget.entry),
        source: widget.source,
      );
      if (saved) {
        await _refresh();
        widget.onSaved?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(ActionItemsCopy.savedReceipt),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _openItem != null
        ? ActionItemsCopy.alreadyRemembered
        : ActionItemsCopy.rememberThis;

    if (widget.compact) {
      return IconButton(
        key: const Key('remember_this_button'),
        tooltip: label,
        onPressed: _busy ? null : _tap,
        icon: Icon(
          _openItem != null
              ? Icons.check_circle_outline
              : Icons.task_alt_outlined,
          size: 20,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        key: const Key('remember_this_button'),
        onPressed: _busy ? null : _tap,
        icon: Icon(
          _openItem != null
              ? Icons.check_circle_outline
              : Icons.task_alt_outlined,
          size: 18,
        ),
        label: Text(label),
      ),
    );
  }
}
