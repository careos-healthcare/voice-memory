import 'dart:io';

import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/api/api_error_message.dart';
import 'package:archiveme_mobile/security/export_pdf_renderer.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum _ExportKind { json, pdf }

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  _ExportKind? _busyKind;
  String? _message;

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
      final file = kind == _ExportKind.pdf
          ? File('${dir.path}/${ExportPdfRenderer.fileName}')
          : File('${dir.path}/archiveme_export.json');
      if (kind == _ExportKind.pdf) {
        await file.writeAsBytes(await ExportPdfRenderer.render(payload));
      } else {
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
              'Exports your locally saved reflections as JSON or PDF. '
              'Internal sync paths and audio file locations are not included. '
              'Sign in and sync first if you want a server-backed export.',
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
