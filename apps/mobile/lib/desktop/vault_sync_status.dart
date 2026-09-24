import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';

/// Encryption health shown on the vault indicator.
enum VaultEncryptionHealth { protected, unavailable }

/// Peer channel status. Direct peers stay off while P2P is disabled.
enum PeerSyncStatus { off, idle, syncing, waiting, error }

/// Snapshot for the vault and peer-sync indicator.
class VaultSyncStatus {
  const VaultSyncStatus({
    required this.encryption,
    required this.peers,
    this.lastSyncedAt,
  });

  VaultSyncStatus.compose({
    required bool encryptionEnabled,
    required bool p2pEnabled,
    SyncStatusSnapshot? sync,
    DateTime? lastSyncedAt,
  }) : encryption = encryptionEnabled
           ? VaultEncryptionHealth.protected
           : VaultEncryptionHealth.unavailable,
       peers = _peers(p2pEnabled: p2pEnabled, sync: sync),
       lastSyncedAt = lastSyncedAt ?? sync?.sync.lastCompletedAt;

  /// Live reading from the encryption gate, capability flag, and sync snapshot.
  VaultSyncStatus.fromApp({
    SyncStatusSnapshot? sync,
    DateTime? lastSyncedAt,
  }) : this.compose(
         encryptionEnabled: SecureSqliteLockService.encryptionEnabled,
         p2pEnabled: V1CapabilityRegistry.p2pAndWebRtc,
         sync: sync,
         lastSyncedAt: lastSyncedAt,
       );

  /// Calm local reading used when sync services are not mounted.
  static const localFallback = VaultSyncStatus(
    encryption: VaultEncryptionHealth.unavailable,
    peers: PeerSyncStatus.off,
  );

  final VaultEncryptionHealth encryption;
  final PeerSyncStatus peers;
  final DateTime? lastSyncedAt;

  String get encryptionLabel => switch (encryption) {
    VaultEncryptionHealth.protected => 'Encrypted',
    VaultEncryptionHealth.unavailable => 'Encryption off',
  };

  String get peerLabel => switch (peers) {
    PeerSyncStatus.off => 'Peers off',
    PeerSyncStatus.idle => 'Peers idle',
    PeerSyncStatus.syncing => 'Peers syncing',
    PeerSyncStatus.waiting => 'Peers waiting',
    PeerSyncStatus.error => 'Peer sync needs attention',
  };

  String get lastSyncedLabel {
    final at = lastSyncedAt?.toLocal();
    if (at == null) return 'Not synced yet';
    final month = at.month.toString().padLeft(2, '0');
    final day = at.day.toString().padLeft(2, '0');
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    return 'Last synced $month-$day $hour:$minute';
  }

  static PeerSyncStatus _peers({
    required bool p2pEnabled,
    required SyncStatusSnapshot? sync,
  }) {
    if (!p2pEnabled) return PeerSyncStatus.off;
    return switch (sync?.visualKind) {
      SyncStatusVisualKind.syncing => PeerSyncStatus.syncing,
      SyncStatusVisualKind.error => PeerSyncStatus.error,
      SyncStatusVisualKind.waiting ||
      SyncStatusVisualKind.offline => PeerSyncStatus.waiting,
      SyncStatusVisualKind.pending ||
      SyncStatusVisualKind.idle ||
      null => PeerSyncStatus.idle,
    };
  }
}
