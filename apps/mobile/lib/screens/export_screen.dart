import 'dart:io';

import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/api/api_error_message.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _exportAndShare() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final payload = await PrivateDataService(
        journalStore: AppServices.instance.journalStore,
      ).buildSanitizedExport();
      final json = payload.toJson();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/archiveme_export.json');
      await file.writeAsString(json);
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'ArchiveMe journal export');
      await BetaAnalyticsHooks.exportResult(success: true);
      setState(
        () => _message = 'Export ready (${payload.entries.length} entries).',
      );
    } catch (e, stackTrace) {
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
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Export',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Exports your locally saved reflections as JSON. '
              'Internal sync paths and audio file locations are not included. '
              'Sign in and sync first if you want a server-backed export.',
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
              label: Text(_busy ? 'Exporting…' : 'Export and share JSON'),
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