import 'dart:async';

import 'package:archiveme_mobile/features/archive/views/book_export_view.dart';
import 'package:archiveme_mobile/features/archive/views/calendar_view.dart';
import 'package:archiveme_mobile/features/archive/views/map_view.dart';
import 'package:archiveme_mobile/features/archive/views/on_this_day_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';

/// Live journal rows for the history screens.
///
/// Emits the entries already loaded for Archive, then the full local store
/// when it is open. An empty archive stays empty.
Stream<List<JournalEntry>> watchLocalJournalEntries(
  List<JournalEntry> visible,
) async* {
  yield List<JournalEntry>.from(visible);
  if (!AppServices.isInitialized) return;
  yield await AppServices.instance.journal.loadAll();
}

/// Horizontal opener at the top of Archive.
class HistoryHubStrip extends StatefulWidget {
  const HistoryHubStrip({
    required this.entries,
    this.onOpenEntry,
    super.key,
  });

  final List<JournalEntry> entries;
  final ValueChanged<String>? onOpenEntry;

  @override
  State<HistoryHubStrip> createState() => _HistoryHubStripState();
}

class _HistoryHubStripState extends State<HistoryHubStrip> {
  late Stream<List<JournalEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = watchLocalJournalEntries(widget.entries);
  }

  @override
  void didUpdateWidget(HistoryHubStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameEntries(oldWidget.entries, widget.entries)) {
      _entries = watchLocalJournalEntries(widget.entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.textScalerOf(context).scale(36) + 20;
    return StreamBuilder<List<JournalEntry>>(
      stream: _entries,
      initialData: widget.entries,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? widget.entries;
        return SizedBox(
          height: height,
          child: ListView(
            key: const Key('archive_history_hub'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            children: [
              for (final (index, label) in const [
                (0, 'On This Day'),
                (1, 'Calendar'),
                (2, 'Map'),
                (3, 'Printable Journal'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    key: Key('history_open_$index'),
                    visualDensity: VisualDensity.compact,
                    label: Text(label, maxLines: 1),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HistoryHub(
                            entries: entries,
                            initialIndex: index,
                            onOpenEntry: widget.onOpenEntry,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class HistoryHub extends StatefulWidget {
  const HistoryHub({
    required this.entries,
    this.initialIndex = 0,
    this.onOpenEntry,
    this.now,
    super.key,
  });

  final List<JournalEntry> entries;
  final int initialIndex;
  final ValueChanged<String>? onOpenEntry;
  final DateTime? now;

  @override
  State<HistoryHub> createState() => _HistoryHubState();
}

class _HistoryHubState extends State<HistoryHub> {
  late var _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(32) + 16,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (index, label) in const [
                  (0, 'On This Day'),
                  (1, 'Calendar'),
                  (2, 'Map'),
                  (3, 'Export Printable Journal'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('history_tab_$label'),
                      label: Text(label),
                      selected: _index == index,
                      onSelected: (_) => setState(() => _index = index),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body(now)),
        ],
      ),
    );
  }

  Widget _body(DateTime now) {
    switch (_index) {
      case 1:
        return CalendarView(
          entries: widget.entries,
          now: now,
          onOpenEntry: widget.onOpenEntry,
        );
      case 2:
        return MapView(
          entries: widget.entries,
          onOpenEntry: widget.onOpenEntry,
        );
      case 3:
        return BookExportView(entries: widget.entries, now: now);
      default:
        return OnThisDayView(entries: widget.entries, now: now);
    }
  }
}

bool _sameEntries(List<JournalEntry> a, List<JournalEntry> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}
