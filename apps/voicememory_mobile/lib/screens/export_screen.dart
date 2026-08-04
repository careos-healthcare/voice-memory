import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_error_message.dart';
import '../features/archive_export/archive_ownership_copy.dart';
import '../features/archive_export/complete_archive_export.dart';
import '../features/changes/change_thread_projection.dart';
import '../features/changes/change_thread_repository.dart';
import '../security/private_data_service.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/pushed_screen_shell.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  static const String description =
      'Two files, both complete: a document you can read and a '
      'machine-readable file. Each one carries your original timestamps, your '
      'text, every correction you made, evidence links, your Changes history, '
      'and a reference for each recording, plus a manifest naming every field.';

  static const String audioNote =
      'Recordings stay in the vault on this device. The export names each one '
      'so it can be matched to its recording, rather than copying audio out '
      'unprotected.';

  bool _busy = false;
  String? _message;

  /// The Changes projection is part of the export, but a projection failure
  /// must never be a reason the user cannot take their own moments with them.
  Future<ChangeThreadProjection> _changesOrEmpty() async {
    try {
      return await ChangeThreadRepository.refresh();
    } on Object {
      return const ChangeThreadProjection.empty();
    }
  }

  Future<void> _exportAndShare() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bundle = await PrivateDataService(
        journalStore: AppServices.instance.journalStore,
      ).buildCompleteExport(changes: await _changesOrEmpty());

      final dir = await getTemporaryDirectory();
      final readable = File(
        '${dir.path}/${ArchiveExportBundle.readableFileName}',
      );
      final machine = File(
        '${dir.path}/${ArchiveExportBundle.machineReadableFileName}',
      );
      await readable.writeAsString(bundle.readableDocument);
      await machine.writeAsString(bundle.machineReadableJson);

      await Share.shareXFiles([
        XFile(readable.path),
        XFile(machine.path),
      ], subject: 'ArchiveMe archive export');

      final manifest = bundle.manifest;
      setState(
        () => _message =
            'Export ready: ${manifest.entryCount} saved moments '
            '(${manifest.deletedEntryCount} deleted), '
            '${manifest.correctionCount} corrections, '
            '${manifest.changeThreadCount} threads.',
      );
    } catch (e) {
      setState(
        () => _message = userFacingErrorMessage(
          e,
          fallback: 'Export failed. Try again.',
        ),
      );
    } finally {
      setState(() => _busy = false);
    }
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
            for (final promise in ArchiveOwnershipCopy.all)
              Padding(
                key: Key('export_promise_$promise'),
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(promise, style: const TextStyle(height: 1.4)),
              ),
            const SizedBox(height: 12),
            const Text(
              description,
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              audioNote,
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              ArchiveExportManifest.accessNote,
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _exportAndShare,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              label: Text(_busy ? 'Exporting…' : 'Export and share both files'),
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
