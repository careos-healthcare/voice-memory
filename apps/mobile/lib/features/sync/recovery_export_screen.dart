import 'dart:math';

import 'package:archiveme_mobile/features/sync/secure_key_manager.dart';
import 'package:flutter/material.dart';

/// Shows a 12-word phrase and requires it to be entered again.
///
/// Cloud backup stays off until that check succeeds and the account has
/// the premium receipt. [RecoveryExportScreen.restore] accepts the same
/// words on a new device and rebuilds the master key.
class RecoveryExportScreen extends StatefulWidget {
  const RecoveryExportScreen({
    required this.keys,
    required this.hasPremium,
    super.key,
    this.onEnabled,
  }) : restore = false;

  const RecoveryExportScreen.restore({
    required this.keys,
    super.key,
    this.onEnabled,
  }) : hasPremium = true,
       restore = true;

  final SecureKeyManager keys;
  final bool hasPremium;
  final bool restore;
  final VoidCallback? onEnabled;

  @override
  State<RecoveryExportScreen> createState() => _RecoveryExportScreenState();
}

class _RecoveryExportScreenState extends State<RecoveryExportScreen> {
  late final String _phrase;
  late final List<int> _checks;
  final _entry = TextEditingController();
  final _wordEntries = <int, TextEditingController>{};
  var _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phrase = widget.restore ? '' : widget.keys.createRecoveryPhrase();
    _checks = widget.restore
        ? const []
        : SecureKeyManager.selectWordIndexes(_phrase, random: Random(7));
    for (final index in _checks) {
      _wordEntries[index] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    for (final controller in _wordEntries.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      if (widget.restore) {
        await widget.keys.restoreFromPhrase(_entry.text);
      } else {
        final enabled = await widget.keys.enableCloudBackup(
          hasPremium: widget.hasPremium,
          shownPhrase: _phrase,
          confirmedWords: {
            for (final index in _checks) index: _wordEntries[index]!.text,
          },
        );
        if (!enabled) {
          setState(() {
            _error = widget.hasPremium
                ? 'Those words do not match. Check the phrase and try again.'
                : 'Cloud backup needs the premium receipt.';
          });
          return;
        }
      }
      widget.onEnabled?.call();
      if (mounted) {
        setState(() => _error = null);
      }
    } on FormatException {
      setState(() {
        _error = 'Enter the 12-word recovery phrase.';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _phrase.split(' ').where((word) => word.isNotEmpty).toList();
    return Scaffold(
      key: const Key('recovery_export_screen'),
      appBar: AppBar(
        title: Text(widget.restore ? 'Restore key' : 'Recovery phrase'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.restore
                      ? 'Enter the 12 words from the device that first enabled encrypted cloud backup.'
                      : 'Write these 12 words down. They rebuild the encryption key on a new device and are not saved on this phone.',
                ),
                const SizedBox(height: 16),
                if (!widget.restore)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < words.length; i++)
                        Chip(
                          key: Key('recovery_word_$i'),
                          label: Text('${i + 1}. ${words[i]}'),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (widget.restore)
                  TextField(
                    key: const Key('recovery_phrase_entry'),
                    controller: _entry,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Recovery phrase',
                      hintText: 'word word word ...',
                    ),
                  )
                else ...[
                  const Text(
                    'Confirm these words from the phrase before cloud backup can turn on.',
                  ),
                  const SizedBox(height: 12),
                  for (final index in _checks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        key: Key('recovery_word_check_$index'),
                        controller: _wordEntries[index],
                        decoration: InputDecoration(
                          labelText: 'Word ${index + 1}',
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, key: const Key('recovery_phrase_error')),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  key: const Key('recovery_phrase_submit'),
                  onPressed: _checking ? null : _submit,
                  child: Text(
                    widget.restore ? 'Restore key' : 'Verify and enable backup',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
