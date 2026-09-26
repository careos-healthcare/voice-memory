import 'dart:io';

import 'package:archiveme_mobile/features/archive/views/on_this_day_view.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Date range, then a print-ready PDF of the moments in that range.
class BookExportView extends StatefulWidget {
  const BookExportView({
    required this.entries,
    this.now,
    this.onShare,
    super.key,
  });

  final List<JournalEntry> entries;
  final DateTime? now;
  final Future<void> Function(DateTime start, DateTime end)? onShare;

  @override
  State<BookExportView> createState() => _BookExportViewState();
}

class _BookExportViewState extends State<BookExportView> {
  var _pastSixMonths = false;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final range = _range(now);
    final count = widget.entries.where((entry) {
      final day = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      return !day.isBefore(range.$1) && !day.isAfter(range.$2);
    }).length;
    return ListView(
      key: const Key('book_export_view'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Printable journal',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('book_range_year'),
              label: Text('${now.year}'),
              selected: !_pastSixMonths,
              onSelected: (_) => setState(() => _pastSixMonths = false),
            ),
            ChoiceChip(
              key: const Key('book_range_six_months'),
              label: const Text('Past 6 months'),
              selected: _pastSixMonths,
              onSelected: (_) => setState(() => _pastSixMonths = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('$count moments in this range'),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('export_printable_journal'),
          onPressed: _saving ? null : () => _share(range.$1, range.$2),
          child: const Text('Save PDF / Share'),
        ),
      ],
    );
  }

  (DateTime, DateTime) _range(DateTime now) {
    if (_pastSixMonths) {
      return (
        DateTime(now.year, now.month - 6, now.day),
        DateTime(now.year, now.month, now.day),
      );
    }
    return (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31));
  }

  Future<void> _share(DateTime start, DateTime end) async {
    final custom = widget.onShare;
    if (custom != null) {
      await custom(start, end);
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await BookExporter.render(
        entries: [
          for (final entry in widget.entries) historyMomentFromEntry(entry),
        ],
        start: start,
        end: end,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/thoughtprint-journal.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/pdf'),
      ]);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
