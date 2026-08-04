import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../storage/mobile_prefs_store.dart';
import '../browser_bridge_models.dart';
import '../vault_bridge_server.dart';

class BrowserBridgeSettingsSheet extends StatefulWidget {
  const BrowserBridgeSettingsSheet({
    super.key,
    required this.server,
    required this.prefs,
    this.onClose,
  });

  static const autoTaggingPrefsKey = 'browser_bridge_auto_tagging_v1';

  final VaultBridgeServer server;
  final MobilePrefsStore prefs;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required VaultBridgeServer server,
    required MobilePrefsStore prefs,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'browser-bridge-settings',
    builder: (panelContext) => BrowserBridgeSettingsSheet(
      server: server,
      prefs: prefs,
      onClose: () => Navigator.pop(panelContext),
    ),
  );

  @override
  State<BrowserBridgeSettingsSheet> createState() =>
      _BrowserBridgeSettingsSheetState();
}

class _BrowserBridgeSettingsSheetState
    extends State<BrowserBridgeSettingsSheet> {
  List<TrustedBrowserExtension> _extensions = const [];
  BrowserPairingInvitation? _invitation;
  bool _autoTag = true;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object>([
        widget.server.extensions(),
        widget.prefs
            .readBool(BrowserBridgeSettingsSheet.autoTaggingPrefsKey)
            .then((value) => value ?? true),
      ]);
      if (!mounted) return;
      setState(() {
        _extensions = values[0] as List<TrustedBrowserExtension>;
        _autoTag = values[1] as bool;
        _loading = false;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _pair() async {
    try {
      final invitation = await widget.server.createPairingInvitation();
      if (mounted) setState(() => _invitation = invitation);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _revoke(String id) async {
    await widget.server.revoke(id);
    await _load();
  }

  Future<void> _setAutoTag(bool value) async {
    setState(() => _autoTag = value);
    await widget.prefs.writeBool(
      BrowserBridgeSettingsSheet.autoTaggingPrefsKey,
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('browser-bridge-settings-sheet'),
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.webhook_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Encrypted Web Clipper',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          'Loopback only · authenticated extensions',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      children: [
                        if (_error != null)
                          Card(
                            color: theme.colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('Bridge error: $_error'),
                            ),
                          ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                if (_invitation == null) ...[
                                  const Icon(Icons.qr_code_2, size: 56),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Create a one-time 60-second pairing code.',
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    key: const Key(
                                      'browser-bridge-create-pairing',
                                    ),
                                    onPressed: _pair,
                                    icon: const Icon(Icons.link),
                                    label: const Text('Pair browser extension'),
                                  ),
                                ] else ...[
                                  QrImageView(
                                    key: const Key('browser-bridge-pairing-qr'),
                                    data: _invitation!.encode(),
                                    size: 220,
                                    backgroundColor: Colors.white,
                                  ),
                                  Text(
                                    'PIN ${_invitation!.pin}',
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                  Text(
                                    'Expires at '
                                    '${TimeOfDay.fromDateTime(_invitation!.expiresAt.toLocal()).format(context)}',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SwitchListTile(
                          key: const Key('browser-bridge-auto-tagging'),
                          contentPadding: EdgeInsets.zero,
                          value: _autoTag,
                          onChanged: _setAutoTag,
                          title: const Text('Auto-tag clipped articles'),
                          subtitle: const Text(
                            'Map local vectors into relevant semantic clusters.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connected extensions',
                          style: theme.textTheme.titleMedium,
                        ),
                        if (_extensions.isEmpty)
                          const ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('No browsers paired'),
                          ),
                        for (final extension in _extensions)
                          ListTile(
                            key: Key('browser-extension-${extension.id}'),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.extension_outlined),
                            title: Text(extension.name),
                            subtitle: Text(
                              '${extension.clipCount} clips · last seen '
                              '${extension.lastSeenAt.toLocal()}',
                            ),
                            trailing: TextButton(
                              key: Key(
                                'browser-extension-revoke-${extension.id}',
                              ),
                              onPressed: () => _revoke(extension.id),
                              child: const Text('Revoke'),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
