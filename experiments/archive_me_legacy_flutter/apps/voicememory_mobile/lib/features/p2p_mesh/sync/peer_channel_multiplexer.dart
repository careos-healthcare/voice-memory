import 'dart:async';

import 'peer_sync_channel.dart';

typedef PeerPacketSelector = bool Function(Map<String, dynamic> packet);

final class PeerChannelMultiplexer {
  PeerChannelMultiplexer(AuthenticatedPeerSyncChannel source)
    : peerId = source.peerId,
      _source = source {
    _subscription = source.packets.listen(
      _route,
      onError: _closeWithError,
      onDone: close,
    );
  }

  final String peerId;
  final AuthenticatedPeerSyncChannel _source;
  final Map<String, _VirtualPeerChannel> _channels = {};
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  bool _closed = false;

  AuthenticatedPeerSyncChannel channel(
    String name, {
    required PeerPacketSelector accepts,
  }) {
    if (_closed) throw StateError('Peer channel multiplexer is closed.');
    return _channels.putIfAbsent(
      name,
      () => _VirtualPeerChannel(
        peerId: peerId,
        source: _source,
        accepts: accepts,
      ),
    );
  }

  void _route(Map<String, dynamic> packet) {
    for (final channel in _channels.values) {
      if (channel.accepts(packet)) {
        channel.add(packet);
        return;
      }
    }
  }

  void _closeWithError(Object error, StackTrace stackTrace) {
    for (final channel in _channels.values) {
      channel.addError(error, stackTrace);
    }
    unawaited(close());
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await Future.wait(_channels.values.map((channel) => channel.close()));
    _channels.clear();
  }
}

final class _VirtualPeerChannel implements AuthenticatedPeerSyncChannel {
  _VirtualPeerChannel({
    required this.peerId,
    required this.source,
    required this.accepts,
  });

  @override
  final String peerId;
  final AuthenticatedPeerSyncChannel source;
  final PeerPacketSelector accepts;
  final StreamController<Map<String, dynamic>> _packets =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get packets => _packets.stream;

  @override
  Future<void> send(Map<String, dynamic> packet) => source.send(packet);

  void add(Map<String, dynamic> packet) => _packets.add(packet);
  void addError(Object error, StackTrace stackTrace) =>
      _packets.addError(error, stackTrace);
  Future<void> close() => _packets.close();
}
