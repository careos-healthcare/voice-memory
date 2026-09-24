import 'dart:io';

import 'package:archiveme_mobile/api/api_error_message.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/features/export/archive_book_exporter.dart';
import 'package:archiveme_mobile/features/export/obsidian_archive_exporter.dart';
import 'package:archiveme_mobile/security/export_pdf_renderer.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum _ExportKind { json, pdf, book, obsidian }

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  _ExportKind? _busyKind;
  String? _message;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  bool get _busy => _busyKind != null;

  Future<void> _exportAndShare(_ExportKind kind) async {
    setState(() {
      _busyKind = kind;
      _message = null;
    });
    try {
      final payload = await PrivateDataService(
        journalStore: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
      ).buildSanitizedExport();
      final dir = await getTemporaryDirectory();
      final bookEntries = _bookEntries(payload);
      final File file;
      if (kind == _ExportKind.pdf) {
        file = File('${dir.path}/${ExportPdfRenderer.fileName}');
        await file.writeAsBytes(await ExportPdfRenderer.render(payload));
      } else if (kind == _ExportKind.book) {
        file = File('${dir.path}/thoughtprint-archive-book.pdf');
        await file.writeAsBytes(
          await ArchiveBookExporter.export(
            entries: bookEntries,
            start: _rangeStart,
            end: _rangeEnd,
          ),
        );
      } else if (kind == _ExportKind.obsidian) {
        file = File('${dir.path}/thoughtprint-obsidian.zip');
        await file.writeAsBytes(
          ObsidianArchiveExporter.buildZip(
            entries: bookEntries,
            start: _rangeStart,
            end: _rangeEnd,
          ),
        );
      } else {
        file = File('${dir.path}/archiveme_export.json');
        await file.writeAsString(payload.toJson());
      }
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'ArchiveMe journal export');
      await BetaAnalyticsHooks.exportResult(success: true);
      setState(
        () => _message = 'Export ready (${payload.entries.length} entries).',
      );
    } catch (e) {
      await BetaAnalyticsHooks.exportResult(success: false);
      ReleaseLogger.exceptionFailure(
        event: 'export_build_failed',
        category: ReleaseLogCategory.export,
        error: e,
      );
      setState(
        () => _message = userFacingErrorMessage(
          e,
          fallback: 'Export failed. Try again.',
        ),
      );
    } finally {
      setState(() => _busyKind = null);
    }
  }

  List<ArchiveBookEntry> _bookEntries(ArchiveExportPayload payload) {
    final entries = <ArchiveBookEntry>[];
    for (var i = 0; i < payload.entries.length; i++) {
      final raw = payload.entries[i];
      final transcript = raw['transcript'];
      final createdAt = DateTime.tryParse('${raw['createdAt']}');
      if (transcript is! String || createdAt == null) continue;
      entries.add(
        ArchiveBookEntry(
          id: 'entry-$i',
          recordedAt: createdAt,
          transcript: transcript,
        ),
      );
    }
    return entries;
  }

  Future<void> _pickRange({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _rangeStart = picked;
      } else {
        _rangeEnd = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Export',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Exports your locally saved entries as JSON, PDF, an archive book, '
              'or an Obsidian folder. Export stays free. '
              'Internal sync paths are not included.',
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            _ExportButton(
              buttonKey: const Key('export_and_share_button'),
              busy: _busyKind == _ExportKind.json,
              enabled: !_busy,
              label: 'Export and share JSON',
              onPressed: () => _exportAndShare(_ExportKind.json),
            ),
            const SizedBox(height: 12),
            _ExportButton(
              buttonKey: const Key('export_and_share_pdf_button'),
              busy: _busyKind == _ExportKind.pdf,
              enabled: !_busy,
              label: 'Export and share PDF',
              onPressed: () => _exportAndShare(_ExportKind.pdf),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('export_range_start'),
                    onPressed: _busy ? null : () => _pickRange(start: true),
                    child: Text(
                      _rangeStart == null
                          ? 'From any date'
                          : 'From ${_rangeStart!.toIso8601String().substring(0, 10)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('export_range_end'),
                    onPressed: _busy ? null : () => _pickRange(start: false),
                    child: Text(
                      _rangeEnd == null
                          ? 'Until any date'
                          : 'Until ${_rangeEnd!.toIso8601String().substring(0, 10)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ExportButton(
              buttonKey: const Key('export_archive_book_button'),
              busy: _busyKind == _ExportKind.book,
              enabled: !_busy,
              label: 'Export archive book',
              onPressed: () => _exportAndShare(_ExportKind.book),
            ),
            const SizedBox(height: 12),
            _ExportButton(
              buttonKey: const Key('export_obsidian_button'),
              busy: _busyKind == _ExportKind.obsidian,
              enabled: !_busy,
              label: 'Export Obsidian zip',
              onPressed: () => _exportAndShare(_ExportKind.obsidian),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.buttonKey,
    required this.busy,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final bool busy;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: buttonKey,
      onPressed: enabled ? onPressed : null,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.share_outlined),
      label: Text(busy ? 'Exporting…' : label),
    );
  }
}
