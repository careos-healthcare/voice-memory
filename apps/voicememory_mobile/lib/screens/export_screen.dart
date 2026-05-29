import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_services.dart';
import '../widgets/placeholder_panel.dart';
import '../widgets/scaffold_shell.dart';

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
      final json = await AppServices.instance.journalStore.exportJson();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/voicememory_export.json');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'VoiceMemory journal export',
      );
      setState(() => _message = 'Export ready (${json.length} bytes).');
    } catch (e) {
      setState(() => _message = 'Export failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldShell(
      title: 'Export',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PlaceholderPanel(
              title: 'JSON export',
              body: 'Exports all locally saved entries. Does not include server-only data.',
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
