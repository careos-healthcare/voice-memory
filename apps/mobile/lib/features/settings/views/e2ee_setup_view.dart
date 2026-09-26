import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks someone to generate or enter a sync passphrase and confirm they kept it.
class E2eeSetupView extends StatefulWidget {
  const E2eeSetupView({required this.generatePassphrase, super.key});

  final String Function() generatePassphrase;

  static const warning =
      'If you lose this passphrase, your synced data cannot be recovered. We cannot reset it for you. A lost passphrase means lost data.';

  @override
  State<E2eeSetupView> createState() => _E2eeSetupViewState();
}

class _E2eeSetupViewState extends State<E2eeSetupView> {
  late final String _generated = widget.generatePassphrase();
  final _existing = TextEditingController();
  var _useExisting = false;
  var _confirmed = false;

  @override
  void dispose() {
    _existing.dispose();
    super.dispose();
  }

  String get _passphrase => _useExisting ? _existing.text.trim() : _generated;

  @override
  Widget build(BuildContext context) {
    final canContinue = _confirmed && _passphrase.isNotEmpty;
    final warningStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.error,
      fontWeight: FontWeight.w700,
    );
    return Scaffold(
      key: const Key('e2ee_setup_view'),
      appBar: AppBar(title: const Text('Sync passphrase')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const Key('e2ee_generate_passphrase'),
                label: const Text('New passphrase'),
                selected: !_useExisting,
                onSelected: (_) => setState(() => _useExisting = false),
              ),
              ChoiceChip(
                key: const Key('e2ee_enter_passphrase'),
                label: const Text('I already have one'),
                selected: _useExisting,
                onSelected: (_) => setState(() => _useExisting = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(E2eeSetupView.warning, style: warningStyle),
          const SizedBox(height: 16),
          if (_useExisting)
            TextField(
              key: const Key('e2ee_passphrase_input'),
              controller: _existing,
              decoration: const InputDecoration(
                labelText: 'Passphrase',
              ),
              onChanged: (_) => setState(() {}),
            )
          else ...[
            SelectableText(
              _generated,
              key: const Key('e2ee_passphrase_text'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('e2ee_copy_passphrase'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _generated));
              },
              child: const Text('Copy'),
            ),
          ],
          const SizedBox(height: 12),
          CheckboxListTile(
            key: const Key('e2ee_stored_checkbox'),
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            onChanged: (value) => setState(() => _confirmed = value ?? false),
            title: const Text('I have stored this passphrase'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('e2ee_setup_continue'),
            onPressed: canContinue
                ? () => Navigator.of(context).pop(_passphrase)
                : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
