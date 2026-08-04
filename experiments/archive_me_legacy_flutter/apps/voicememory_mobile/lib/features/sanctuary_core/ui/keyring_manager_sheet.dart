import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../shared/ui/glassmorphic_container.dart';

typedef SanctuaryPhraseRevealer = Future<String?> Function();
typedef SanctuaryPhraseVerifier = Future<bool> Function(String phrase);
typedef SanctuaryKeyRotator = Future<String?> Function();
typedef SanctuaryKeyExporter = Future<File?> Function(String password);

final class KeyringManagerSheet extends StatefulWidget {
  const KeyringManagerSheet({
    super.key,
    required this.revealPhrase,
    required this.verifyPhrase,
    required this.rotateSyncKey,
    required this.exportKeys,
    required this.onClose,
  });

  final SanctuaryPhraseRevealer revealPhrase;
  final SanctuaryPhraseVerifier verifyPhrase;
  final SanctuaryKeyRotator rotateSyncKey;
  final SanctuaryKeyExporter exportKeys;
  final VoidCallback onClose;

  @override
  State<KeyringManagerSheet> createState() => _KeyringManagerSheetState();
}

class _KeyringManagerSheetState extends State<KeyringManagerSheet> {
  final _phraseController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _revealedPhrase;
  String? _status;
  bool _busy = false;

  @override
  void dispose() {
    _phraseController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reveal() async {
    setState(() => _busy = true);
    final phrase = await widget.revealPhrase();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _revealedPhrase = phrase;
      _status = phrase == null
          ? 'Device-owner authentication was not completed.'
          : 'Recovery phrase revealed for this session only.';
    });
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final verified = await widget.verifyPhrase(_phraseController.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = verified
          ? 'Recovery phrase verified.'
          : 'Phrase verification failed.';
    });
  }

  Future<void> _rotate() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rotate sync master key?'),
            content: const Text(
              'Existing peer devices must receive the new recovery phrase. '
              'Pending encrypted sync envelopes will be rebuilt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('sanctuary-rotate-confirm'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Rotate key'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final phrase = await widget.rotateSyncKey();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _revealedPhrase = phrase;
      _status = phrase == null
          ? 'Key rotation was cancelled.'
          : 'Sync master key rotated. Save the new phrase now.';
    });
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final output = await widget.exportKeys(_passwordController.text);
      if (!mounted) return;
      setState(() {
        _status = output == null
            ? 'Key export was cancelled.'
            : 'Encrypted key backup saved: ${output.path}';
      });
    } on Object {
      if (mounted) {
        setState(() => _status = 'Use a password of at least 12 characters.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassmorphicContainer(
          key: const Key('sanctuary-keyring-sheet'),
          radius: BorderRadius.circular(32),
          blurSigma: 24,
          padding: const EdgeInsets.all(22),
          child: ListView(
            children: [
              Row(
                children: [
                  const Icon(Icons.key_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sovereign Keyring',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Every sensitive action requires a fresh Face ID, fingerprint, '
                'or device-credential check.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('sanctuary-reveal-phrase'),
                onPressed: _busy ? null : _reveal,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Reveal recovery phrase'),
              ),
              if (_revealedPhrase case final phrase?) ...[
                const SizedBox(height: 12),
                Semantics(
                  label: 'Sensitive recovery phrase',
                  child: Wrap(
                    key: const Key('sanctuary-recovery-words'),
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final indexed in phrase.split(' ').indexed)
                        Chip(label: Text('${indexed.$1 + 1}. ${indexed.$2}')),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                key: const Key('sanctuary-verify-field'),
                controller: _phraseController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Enter all 12 words to verify',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('sanctuary-verify-phrase'),
                onPressed: _busy ? null : _verify,
                child: const Text('Verify phrase'),
              ),
              const Divider(height: 32),
              OutlinedButton.icon(
                key: const Key('sanctuary-rotate-key'),
                onPressed: _busy ? null : _rotate,
                icon: const Icon(Icons.sync_lock),
                label: const Text('Rotate sync master key'),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('sanctuary-export-password'),
                controller: _passwordController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Key-backup password',
                  helperText: 'At least 12 characters',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('sanctuary-export-key'),
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export .sanctuary-key'),
              ),
              if (_status case final status?) ...[
                const SizedBox(height: 12),
                Text(status, key: const Key('sanctuary-keyring-status')),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
