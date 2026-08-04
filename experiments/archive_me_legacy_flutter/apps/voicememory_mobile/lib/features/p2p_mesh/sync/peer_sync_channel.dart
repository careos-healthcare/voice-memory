/// Minimal bridge to a mutually authenticated secure peer channel.
///
/// Discovery, key agreement, framing, and radio selection intentionally live
/// outside CRDT reconciliation. Implementations must emit packets only after
/// authenticating [peerId].
abstract class AuthenticatedPeerSyncChannel {
  String get peerId;

  Stream<Map<String, dynamic>> get packets;

  Future<void> send(Map<String, dynamic> packet);
}
