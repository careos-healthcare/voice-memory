import 'package:archiveme_mobile/features/sync/mesh_sync_manager.dart';
import 'package:archiveme_mobile/features/sync/mesh_sync_state.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Diagnostic dashboard for local mesh peers, the vector queue, and keys.
class SyncStatusCenterScreen extends ConsumerWidget {
  const SyncStatusCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(meshSyncManagerProvider);
    return Scaffold(
      key: const Key('sync_status_center_screen'),
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(title: const Text('Mesh sync')),
      body: asyncState.when(
        loading: () => const Center(child: Text('Checking keys')),
        error: (error, stackTrace) => const Center(
          child: Text('Mesh status is unavailable.'),
        ),
        data: (state) => _MeshStatusBody(state: state),
      ),
    );
  }
}

class _MeshStatusBody extends ConsumerWidget {
  const _MeshStatusBody({required this.state});

  final MeshSyncState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(meshSyncManagerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spacing4),
      children: [
        Text('Active Peer Radar', style: AppTokens.section()),
        const SizedBox(height: AppTokens.spacing2),
        if (!state.meshEnabled)
          const Text('Mesh discovery is off on this device.')
        else if (state.peers.isEmpty)
          const Text('No devices on this mesh.')
        else
          for (final peer in state.peers) _PeerRow(peer: peer),
        const SizedBox(height: AppTokens.spacing2),
        Text(
          'In ${state.bytesPerSecondIn} B/s · Out ${state.bytesPerSecondOut} B/s',
          key: const Key('mesh_transfer_rates'),
        ),
        const SizedBox(height: AppTokens.spacing4),
        Text('Indexing queue', style: AppTokens.section()),
        const SizedBox(height: AppTokens.spacing2),
        LinearProgressIndicator(
          key: const Key('mesh_vector_queue'),
          value: state.queueFraction,
        ),
        const SizedBox(height: AppTokens.spacing2),
        Text('${state.pendingVectors} embeddings waiting'),
        const SizedBox(height: AppTokens.spacing4),
        Text('Key integrity', style: AppTokens.section()),
        const SizedBox(height: AppTokens.spacing2),
        Text(
          state.keyValid
              ? 'Keys match ${state.keyFingerprint}'
              : 'Keys need attention',
          key: const Key('mesh_key_badge'),
        ),
        const SizedBox(height: AppTokens.spacing3),
        FilledButton(
          key: const Key('mesh_rotate_keys'),
          onPressed: manager.rotateMasterKey,
          child: const Text('Rotate Master Keys'),
        ),
        const SizedBox(height: AppTokens.spacing2),
        OutlinedButton(
          key: const Key('mesh_trigger_scan'),
          onPressed: manager.scan,
          child: const Text('Trigger Mesh Scan'),
        ),
        const SizedBox(height: AppTokens.spacing2),
        SwitchListTile(
          key: const Key('mesh_log_toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Mesh log'),
          value: state.loggingEnabled,
          onChanged: (enabled) => manager.setLogging(enabled: enabled),
        ),
        if (state.loggingEnabled)
          for (final line in state.logs) Text(line, key: Key('mesh_log_$line')),
      ],
    );
  }
}

class _PeerRow extends StatelessWidget {
  const _PeerRow({required this.peer});

  final MeshPeer peer;

  @override
  Widget build(BuildContext context) {
    final syncLabel = switch (peer.sync) {
      MeshPeerSync.inSync => 'In sync',
      MeshPeerSync.catchingUp => 'Catching up',
      MeshPeerSync.idle => 'Idle',
    };
    return ListTile(
      key: Key('mesh_peer_${peer.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(peer.name),
      subtitle: Text('${peer.ping.inMilliseconds} ms · $syncLabel'),
    );
  }
}
