import 'dart:ui';

import 'package:flutter/material.dart';

import 'healthkit_connector.dart';
import 'spotify_connector.dart';

class DataSourcesSheet extends StatefulWidget {
  const DataSourcesSheet({
    super.key,
    this.health,
    this.spotify,
    required this.showExternalNodes,
    required this.onExternalVisibilityChanged,
    this.onDataChanged,
  });

  final HealthConnectorController? health;
  final SpotifyConnectorController? spotify;
  final bool showExternalNodes;
  final ValueChanged<bool> onExternalVisibilityChanged;
  final VoidCallback? onDataChanged;

  static Future<void> show(
    BuildContext context, {
    HealthConnectorController? health,
    SpotifyConnectorController? spotify,
    required bool showExternalNodes,
    required ValueChanged<bool> onExternalVisibilityChanged,
    VoidCallback? onDataChanged,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DataSourcesSheet(
      health: health,
      spotify: spotify,
      showExternalNodes: showExternalNodes,
      onExternalVisibilityChanged: onExternalVisibilityChanged,
      onDataChanged: onDataChanged,
    ),
  );

  @override
  State<DataSourcesSheet> createState() => _DataSourcesSheetState();
}

class _DataSourcesSheetState extends State<DataSourcesSheet> {
  late bool _healthEnabled = widget.health?.enabled ?? false;
  late bool _showExternalNodes = widget.showExternalNodes;
  bool _spotifyConnected = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshSpotifyState();
  }

  Future<void> _refreshSpotifyState() async {
    final connected = await widget.spotify?.connected ?? false;
    if (mounted) setState(() => _spotifyConnected = connected);
  }

  Future<void> _toggleHealth(bool value) async {
    final health = widget.health;
    if (health == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final enabled = value ? await health.enable() : false;
      if (!value) await health.disable();
      if (mounted) setState(() => _healthEnabled = enabled);
      if (enabled) widget.onDataChanged?.call();
    } on Object {
      if (mounted) {
        setState(() => _error = 'Apple Health permission was not granted.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSpotify() async {
    final spotify = widget.spotify;
    if (spotify == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_spotifyConnected) {
        await spotify.disconnect();
      } else {
        await spotify.connect();
      }
      await _refreshSpotifyState();
      widget.onDataChanged?.call();
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Spotify could not connect. Unlock the biometric vault and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .82,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Data Sources',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Passive context is encrypted locally first. Cross-device '
                  'sync uses only zero-knowledge encrypted CRDT envelopes.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const Key('data-sources-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SwitchListTile(
                  key: const Key('health-data-toggle'),
                  value: _healthEnabled,
                  onChanged: _busy || widget.health == null
                      ? null
                      : _toggleHealth,
                  secondary: const Icon(
                    Icons.favorite,
                    color: Color(0xFFFF4D7D),
                  ),
                  title: const Text('Apple Health'),
                  subtitle: Text(
                    widget.health == null
                        ? 'Available on supported iPhone devices'
                        : _lastSync(widget.health!.lastSyncAt),
                  ),
                ),
                ListTile(
                  key: const Key('spotify-data-source'),
                  leading: const Icon(
                    Icons.music_note,
                    color: Color(0xFF1ED760),
                  ),
                  title: const Text('Spotify'),
                  subtitle: Text(
                    widget.spotify == null
                        ? 'Spotify client ID is not configured'
                        : _spotifyConnected
                        ? _lastSync(widget.spotify!.lastSyncAt)
                        : 'Connect recently played music',
                  ),
                  trailing: FilledButton.tonal(
                    key: const Key('spotify-connect-button'),
                    onPressed: _busy || widget.spotify == null
                        ? null
                        : _toggleSpotify,
                    child: Text(_spotifyConnected ? 'Disconnect' : 'Connect'),
                  ),
                ),
                const Divider(height: 32),
                SwitchListTile(
                  key: const Key('external-graph-visibility-toggle'),
                  value: _showExternalNodes,
                  onChanged: (value) {
                    setState(() => _showExternalNodes = value);
                    widget.onExternalVisibilityChanged(value);
                  },
                  secondary: const Icon(Icons.hub_outlined),
                  title: const Text('Show external context on graph'),
                  subtitle: const Text(
                    'Hide passive nodes without deleting their encrypted data.',
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _lastSync(DateTime? value) => value == null
    ? 'Not synced yet'
    : 'Last synced ${value.toLocal().toString().substring(0, 16)}';
