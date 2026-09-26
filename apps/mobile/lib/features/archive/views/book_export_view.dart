import 'dart:io';

import 'package:archiveme_mobile/features/archive/views/on_this_day_view.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/features/export/services/qr_audio_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Date range, then a print-ready PDF of the moments in that range.
class BookExportView extends StatefulWidget {
  const BookExportView({
    required this.entries,
    this.now,
    this.onShare,
    this.audioQr,
    super.key,
  });

  final List<JournalEntry> entries;
  final DateTime? now;
  final Future<void> Function(DateTime start, DateTime end)? onShare;
  final QrAudioService? audioQr;

  @override
  State<BookExportView> createState() => _BookExportViewState();
}

class _BookExportViewState extends State<BookExportView> {
  var _pastSixMonths = false;
  var _includeAudioQr = false;
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
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('book_audio_qr_toggle'),
          contentPadding: EdgeInsets.zero,
          value: _includeAudioQr,
          onChanged: _saving
              ? null
              : (value) => setState(() => _includeAudioQr = value),
          title: const Text(
            'Include playable audio QR codes (requires temporary cloud upload)',
          ),
          subtitle: const Text(
            'This temporarily pushes encrypted audio to the cloud to generate the link. Each link expires after 30 days.',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('export_printable_journal'),
          onPressed: _saving ? null : () => _share(range.$1, range.$2),
          child: const Text('Save PDF / Share'),
        ),
      ],
    );
  }

  bool _inRange(JournalEntry entry, DateTime start, DateTime end) {
    final day = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    return !day.isBefore(start) && !day.isAfter(end);
  }

  Future<QrAudioBatch> _audioLinks(List<JournalEntry> entries) async {
    final injected = widget.audioQr;
    if (injected != null) return injected.linksFor(entries);
    if (!AppServices.isInitialized) {
      final withAudio = entries.where((entry) {
        final path = entry.localAudioPath?.trim().toLowerCase() ?? '';
        return path.endsWith('.m4a');
      }).length;
      return QrAudioBatch(urls: const {}, skipped: withAudio);
    }
    return QrAudioService.http(
      AppServices.instance.httpTransport,
    ).linksFor(entries);
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
      final selected = [
        for (final entry in widget.entries)
          if (_inRange(entry, start, end)) entry,
      ];
      final audio = _includeAudioQr
          ? await _audioLinks(selected)
          : const QrAudioBatch(urls: {}, skipped: 0);
      if (audio.skipped > 0 && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Some recordings stayed on this phone. Those pages have no playable code.',
            ),
          ),
        );
      }
      final bytes = await BookExporter.render(
        entries: [
          for (final entry in widget.entries) historyMomentFromEntry(entry),
        ],
        start: start,
        end: end,
        audioQrUrls: audio.urls,
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
