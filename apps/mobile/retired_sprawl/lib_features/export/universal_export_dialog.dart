import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/features/export/universal_export_markdown.dart';
import 'package:archiveme_mobile/features/export/universal_export_models.dart';
import 'package:archiveme_mobile/features/export/universal_export_service.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Shows the archive size, then compresses with a cancelable progress dialog.
Future<File?> showUniversalExportDialog({
  required BuildContext context,
  required List<UniversalExportEntry> entries,
  required File databaseFile,
  Directory? outputDirectory,
  UniversalExportService? service,
  UniversalExportDelivery delivery = UniversalExportDelivery.share,
  Future<void> Function(File file)? share,
}) async {
  final directory = outputDirectory ?? await getTemporaryDirectory();
  if (!context.mounted) return null;
  return showDialog<File>(
    context: context,
    barrierDismissible: false,
    builder: (context) => UniversalExportDialog(
      request: UniversalExportRequest(
        entries: entries,
        databaseFile: databaseFile,
        outputDirectory: directory,
      ),
      service: service ?? UniversalExportService(share: share),
      delivery: delivery,
    ),
  );
}

/// Estimate, then compress, with a cancel button on both steps.
class UniversalExportDialog extends StatefulWidget {
  const UniversalExportDialog({
    required this.request,
    required this.service,
    required this.delivery,
    super.key,
  });

  final UniversalExportRequest request;
  final UniversalExportService service;
  final UniversalExportDelivery delivery;

  @override
  State<UniversalExportDialog> createState() => _UniversalExportDialogState();
}

class _UniversalExportDialogState extends State<UniversalExportDialog> {
  final ExecutionCancelToken _cancel = ExecutionCancelToken();
  ExportSizeEstimate? _estimate;
  UniversalExportProgress? _progress;
  String? _error;
  var _running = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEstimate());
  }

  Future<void> _loadEstimate() async {
    try {
      final estimate = await widget.service.estimate(widget.request);
      if (!mounted || _cancel.isCancelled) return;
      setState(() => _estimate = estimate);
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'Could not measure the archive.');
    }
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _error = null;
      _progress = const UniversalExportProgress(
        label: 'Preparing',
        fraction: 0,
      );
    });
    try {
      final file = await widget.service.export(
        widget.request,
        cancel: _cancel,
        delivery: widget.delivery,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } on ExecutionCancelledException {
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = 'Export failed. Try again.';
      });
    }
  }

  void _cancelExport() {
    _cancel.cancel();
    if (!_running) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;
    final progress = _progress;
    return AlertDialog(
      key: const Key('universal_export_dialog'),
      title: const Text('Export your archive'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (estimate == null && _error == null)
            const Text('Measuring archive size…')
          else if (estimate != null)
            Text(
              '${formatExportBytes(estimate.totalBytes)} before compression',
              key: const Key('universal_export_estimate'),
              style: AppTokens.body(),
            ),
          if (estimate != null) ...[
            const SizedBox(height: AppTokens.spacing2),
            Text(
              '${estimate.entryCount} moments, ${estimate.recordingCount} recordings, and the database.',
              style: AppTokens.body(),
            ),
          ],
          if (_running && progress != null) ...[
            const SizedBox(height: AppTokens.spacing4),
            Text(progress.label, key: const Key('universal_export_progress')),
            const SizedBox(height: AppTokens.spacing2),
            LinearProgressIndicator(value: progress.fraction),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppTokens.spacing3),
            Text(_error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('universal_export_cancel'),
          onPressed: _cancelExport,
          child: const Text('Cancel'),
        ),
        if (!_running)
          FilledButton(
            key: const Key('universal_export_create'),
            onPressed: estimate == null ? null : _start,
            child: const Text('Create archive'),
          ),
      ],
    );
  }
}
