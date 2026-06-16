import 'package:flutter/material.dart';

import '../../features/fact_ledger/archive_fact.dart';
import '../../features/fact_ledger/fact_ledger_store.dart';
import '../../features/timeline/timeline_entry_display.dart';
import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import 'fact_editor_sheet.dart';

/// Opens the fact editor for one entry. Creates nothing until the user saves.
class SaveAsFactButton extends StatefulWidget {
  const SaveAsFactButton({
    super.key,
    required this.entry,
    required this.store,
    this.source = 'entry_detail',
    this.compact = false,
    this.onSaved,
  });

  final JournalEntry entry;
  final FactLedgerStore store;
  final String source;
  final bool compact;
  final VoidCallback? onSaved;

  @override
  State<SaveAsFactButton> createState() => _SaveAsFactButtonState();
}

class _SaveAsFactButtonState extends State<SaveAsFactButton> {
  var _hasFact = false;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final has = await widget.store.entryHasFact(widget.entry.id);
    if (!mounted) return;
    setState(() {
      _hasFact = has;
      _loading = false;
    });
  }

  Future<void> _tap() async {
    if (_busy || _loading) return;
    if (_hasFact) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(FactLedgerCopy.alreadySaved),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.saveDetailTapped,
      source: widget.source,
    );
    setState(() => _busy = true);
    try {
      final saved = await showFactEditorSheet(
        context,
        store: widget.store,
        entry: widget.entry,
        prefillLabel: timelineEntryTitle(widget.entry),
        source: widget.source,
      );
      if (saved) {
        await _refresh();
        widget.onSaved?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(FactLedgerCopy.savedReceipt),
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
    final label = _hasFact
        ? FactLedgerCopy.alreadySaved
        : FactLedgerCopy.saveDetail;

    if (widget.compact) {
      return IconButton(
        key: const Key('save_as_fact_button'),
        tooltip: label,
        onPressed: _busy ? null : _tap,
        icon: Icon(
          _hasFact ? Icons.fact_check_outlined : Icons.note_add_outlined,
          size: 20,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        key: const Key('save_as_fact_button'),
        onPressed: _busy ? null : _tap,
        icon: Icon(
          _hasFact ? Icons.fact_check_outlined : Icons.note_add_outlined,
          size: 18,
        ),
        label: Text(label),
      ),
    );
  }
}
