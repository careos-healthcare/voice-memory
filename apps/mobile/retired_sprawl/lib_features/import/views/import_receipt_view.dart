import 'dart:async';

import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:flutter/material.dart';

/// Shown after a Voice Memo has been transcribed, before it is saved.
class ImportReceiptView extends StatefulWidget {
  const ImportReceiptView({
    required this.transcript,
    required this.recordedAt,
    required this.onSave,
    super.key,
  });

  static const headline = 'Voice Memo Imported';
  static const saveLabel = 'Save to Archive';

  final String transcript;
  final DateTime recordedAt;
  final Future<void> Function() onSave;

  @override
  State<ImportReceiptView> createState() => _ImportReceiptViewState();
}

class _ImportReceiptViewState extends State<ImportReceiptView> {
  var _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(ImportReceiptView.headline),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ImportReceiptView.headline,
              key: const Key('import_receipt_headline'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Original Recording Date: ${LocaleDateFormat.dateTime(context, widget.recordedAt)}',
              key: const Key('import_receipt_entry_date'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.transcript,
                  key: const Key('import_receipt_transcript'),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('import_receipt_save'),
                onPressed: _saving ? null : _save,
                child: const Text(ImportReceiptView.saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pushes the receipt on the root navigator after transcription.
Future<void> presentVoiceMemoReceipt({
  required JournalEntry entry,
  required Future<void> Function(JournalEntry entry) save,
  int attempt = 0,
}) async {
  final navigator = appRootNavigatorKey.currentState;
  if (navigator == null) {
    if (attempt >= 8) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        presentVoiceMemoReceipt(entry: entry, save: save, attempt: attempt + 1),
      );
    });
    return;
  }
  await navigator.push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ImportReceiptView(
        transcript: entry.transcript,
        recordedAt: entry.createdAt,
        onSave: () => save(entry),
      ),
    ),
  );
}
