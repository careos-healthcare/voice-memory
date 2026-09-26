import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/archive/views/on_this_day_view.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/features/export/services/qr_audio_service.dart';
import 'package:archiveme_mobile/features/export/views/pod_checkout_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// A printed keepsake of the year, then a date range and the moments in it.
class BookExportView extends StatefulWidget {
  const BookExportView({
    required this.entries,
    this.now,
    this.onShare,
    this.onPrint,
    this.onOrderPrinted,
    this.audioQr,
    super.key,
  });

  final List<JournalEntry> entries;
  final DateTime? now;
  final Future<void> Function(DateTime start, DateTime end)? onShare;
  final Future<void> Function(DateTime start, DateTime end)? onPrint;
  final Future<void> Function(DateTime start, DateTime end)? onOrderPrinted;
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
    final count = widget.entries
        .where((entry) => _inRange(entry, range.$1, range.$2))
        .length;
    final theme = Theme.of(context);
    return ListView(
      key: const Key('book_export_view'),
      padding: const EdgeInsets.all(16),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End-of-year keepsake',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.accentSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your year in your own words, printed.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'A small book of this year, ready to keep or give as a gift.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('book_print_at_home'),
          onPressed: _saving ? null : () => _print(range.$1, range.$2),
          child: const Text('Print at Home (AirPrint)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('export_printable_journal'),
          onPressed: _saving ? null : () => _share(range.$1, range.$2),
          child: const Text('Save PDF / Share'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('book_order_printed'),
          onPressed: _saving ? null : () => _orderPrinted(range.$1, range.$2),
          child: const Text('Order a printed book'),
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

  Future<Uint8List> _pdfBytes(DateTime start, DateTime end) async {
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
    return BookExporter.render(
      entries: [
        for (final entry in widget.entries) historyMomentFromEntry(entry),
      ],
      start: start,
      end: end,
      audioQrUrls: audio.urls,
    );
  }

  Future<void> _print(DateTime start, DateTime end) async {
    final custom = widget.onPrint;
    if (custom != null) {
      await custom(start, end);
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await _pdfBytes(start, end);
      await Printing.layoutPdf(
        name: 'Thoughtprint',
        format: PdfPageFormat.a5,
        dynamicLayout: false,
        onLayout: (format) async => bytes,
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Printing is not available on this device.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _orderPrinted(DateTime start, DateTime end) async {
    final custom = widget.onOrderPrinted;
    if (custom != null) {
      await custom(start, end);
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await _pdfBytes(start, end);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PodCheckoutView(pdf: bytes),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share(DateTime start, DateTime end) async {
    final custom = widget.onShare;
    if (custom != null) {
      await custom(start, end);
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await _pdfBytes(start, end);
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
