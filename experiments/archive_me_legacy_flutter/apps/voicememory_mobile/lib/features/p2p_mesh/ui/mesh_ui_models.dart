import '../mesh_models.dart';

enum MeshAvailability { unavailable, scanning, available }

enum MeshPairingState { unpaired, awaitingConfirmation, paired }

enum MeshSyncState { idle, syncing, complete, failed }

enum MeshHapticEvent { selection, confirmation, warning }

typedef MeshHapticCallback = void Function(MeshHapticEvent event);

/// Presentation-only state for a discovered peer.
///
/// The transport-owned [MeshPeer] remains the source of peer identity while
/// short-lived pairing and sync state can be supplied by any controller.
class MeshPeerViewState {
  const MeshPeerViewState({
    required this.peer,
    this.isTrusted = false,
    this.pairingState = MeshPairingState.unpaired,
    this.sas,
    this.syncState = MeshSyncState.idle,
    this.syncProgress = 0,
    this.syncError,
  }) : assert(syncProgress >= 0 && syncProgress <= 1),
       assert(
         pairingState != MeshPairingState.awaitingConfirmation || sas != null,
       );

  final MeshPeer peer;
  final bool isTrusted;
  final MeshPairingState pairingState;
  final String? sas;
  final MeshSyncState syncState;
  final double syncProgress;
  final String? syncError;

  bool get canBeam => isTrusted && pairingState == MeshPairingState.paired;
}
