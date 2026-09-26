import 'dart:io';

import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/features/export/full_archive_transfer.dart';
import 'package:archiveme_mobile/features/export/import_guides.dart';
import 'package:archiveme_mobile/features/export/services/archive_transfer_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Settings export/import for a passphrase-sealed journal archive.
class ArchiveTransferScreen extends StatefulWidget {
  const ArchiveTransferScreen({super.key});

  @override
  State<ArchiveTransferScreen> createState() => _ArchiveTransferScreenState();
}

class _ArchiveTransferScreenState extends State<ArchiveTransferScreen> {
  final _passphrase = TextEditingController();
  var _busy = false;
  String? _status;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<List<int>> _accountKey() async {
    final passphrase = _passphrase.text;
    final existing = await AccountSyncKey.readBundle();
    if (existing != null) {
      return AccountSyncKey.unwrap(
        wrapped: existing.wrappedByPassphrase,
        secret: passphrase,
      );
    }
    final accountKey = AccountSyncKey.generate();
    final bundle = await AccountSyncKey.wrap(
      accountKey: accountKey,
      passphrase: passphrase,
      recoveryPhrase: passphrase,
    );
    await AccountSyncKey.storeBundle(bundle);
    return accountKey;
  }

  Future<void> _export() async {
    if (_passphrase.text.trim().isEmpty || !AppServices.isInitialized) return;
    setState(() => _busy = true);
    try {
      final saved = await AppServices.instance.journal.loadAll();
      final bytes = await ArchiveTransferService.exportZip(
        accountKey: await _accountKey(),
        entries: saved,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/thoughtprint-archive.zip');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _status = 'Sealed archive written to ${file.path}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_passphrase.text.trim().isEmpty) return;
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    setState(() => _busy = true);
    try {
      final bundle = await FullArchiveTransfer.importZip(
        accountKey: await _accountKey(),
        bytes: bytes,
      );
      if (!mounted) return;
      setState(
        () =>
            _status = 'Read ${bundle.entries.length} entries from the archive.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export / Import')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(ImportGuides.dayOne, key: const Key('import_guide_day_one')),
          const SizedBox(height: 8),
          Text(
            ImportGuides.dayOnePhotos,
            key: const Key('import_guide_day_one_photos'),
          ),
          const SizedBox(height: 12),
          Text(
            ImportGuides.appleNotes,
            key: const Key('import_guide_apple_notes'),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('archive_transfer_passphrase'),
            controller: _passphrase,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passphrase'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _export,
            child: const Text('Export sealed archive'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _import,
            child: const Text('Import sealed archive'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!),
          ],
        ],
      ),
    );
  }
}
