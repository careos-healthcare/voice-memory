import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/features/export/journal_bulk_export_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Settings screen for bulk journal export in open JSON format.
class JournalBulkExportScreen extends StatefulWidget {
  const JournalBulkExportScreen({super.key});

  @override
  State<JournalBulkExportScreen> createState() =>
      _JournalBulkExportScreenState();
}

class _JournalBulkExportScreenState extends State<JournalBulkExportScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _export() async {
    if (!AppServices.isInitialized) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = JournalBulkExportService(
        repository: JournalSqliteRepository(AppServices.instance.sqliteDatabase),
      );
      final payload = await service.buildExport();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/archiveme_journal_export.json');
      await file.writeAsString(payload.toJsonString());
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'ArchiveMe journal export',
      );
      setState(
        () => _message = 'Exported ${payload.entryCount} entries to JSON.',
      );
    } catch (e, stackTrace) {
      setState(() => _message = 'Export failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Export my journal',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Exports non-deleted journal entries as open JSON via local SQLite. '
              'Includes transcripts, reflections, timestamps, and insight citations. '
              'Share sheet only — nothing is uploaded automatically.',
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('journal_bulk_export_button'),
              onPressed: _busy ? null : _export,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              label: Text(_busy ? 'Exporting…' : 'Export my journal'),
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