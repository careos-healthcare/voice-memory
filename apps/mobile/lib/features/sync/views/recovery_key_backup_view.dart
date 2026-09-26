import 'dart:async';

import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/features/sync/services/device_pairing_service.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Shows a new 24-word key, then requires the words to be typed back.
class RecoveryKeyBackupView extends StatefulWidget {
  const RecoveryKeyBackupView({
    required this.phrase,
    this.onPrint,
    super.key,
  });

  final String phrase;
  final Future<void> Function(String phrase)? onPrint;

  static Future<void> printPhrase(String phrase) {
    return Printing.layoutPdf(
      name: 'Thoughtprint recovery key',
      onLayout: (format) async {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: format,
            build: (context) => pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Text(
                'Thoughtprint recovery key\n\n$phrase\n\nKeep this page private.',
              ),
            ),
          ),
        );
        return doc.save();
      },
    );
  }

  static const instruction =
      'Write down these 24 words in order. They are the only way to open your journal on a new phone if this one is lost.';

  @override
  State<RecoveryKeyBackupView> createState() => _RecoveryKeyBackupViewState();
}

class _RecoveryKeyBackupViewState extends State<RecoveryKeyBackupView> {
  final _typed = TextEditingController();
  var _checking = false;
  var _iCloud = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _matches =>
      _typed.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
      widget.phrase.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Widget build(BuildContext context) {
    final words = widget.phrase.trim().split(RegExp(r'\s+'));
    return Scaffold(
      key: const Key('recovery_key_backup'),
      appBar: AppBar(title: const Text('Recovery key')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(RecoveryKeyBackupView.instruction),
          const SizedBox(height: 16),
          if (!_checking) ...[
            for (var i = 0; i < words.length; i++)
              Text('${i + 1}. ${words[i]}', key: Key('recovery_word_${i + 1}')),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('recovery_wrote_them_down'),
              onPressed: AccountSyncKey.verifyRecoveryPhrase(widget.phrase)
                  ? () => setState(() => _checking = true)
                  : null,
              child: const Text("I've saved it"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('recovery_print'),
              onPressed: () {
                final print =
                    widget.onPrint ?? RecoveryKeyBackupView.printPhrase;
                unawaited(print(widget.phrase));
              },
              child: const Text('Print or save as PDF'),
            ),
          ] else ...[
            const Text(
              'Type the 24 words, in order, to confirm you saved them.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('recovery_verify_input'),
              controller: _typed,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('recovery_verify_continue'),
              onPressed: _matches
                  ? () => Navigator.of(context).pop(
                      _iCloud
                          ? MasterKeyKeychainScope.iCloud
                          : MasterKeyKeychainScope.thisDeviceOnly,
                    )
                  : null,
              child: const Text('Confirm recovery key'),
            ),
            SwitchListTile(
              key: const Key('recovery_icloud'),
              contentPadding: EdgeInsets.zero,
              value: _iCloud,
              onChanged: (value) => setState(() => _iCloud = value ?? false),
              title: const Text('Keep this key in iCloud Keychain'),
              subtitle: const Text(
                'A new iPhone on the same iCloud account can unlock after its first unlock.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
