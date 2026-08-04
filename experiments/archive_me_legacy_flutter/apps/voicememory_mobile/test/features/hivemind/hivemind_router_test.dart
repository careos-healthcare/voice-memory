import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/hivemind/hivemind_mesh_router.dart';
import 'package:voicememory_mobile/features/hivemind/hivemind_models.dart';
import 'package:voicememory_mobile/features/p2p_mesh/sync/peer_channel_multiplexer.dart';
import 'package:voicememory_mobile/features/p2p_mesh/sync/peer_sync_channel.dart';

void main() {
  test(
    'capability contracts fail closed for unavailable native transports',
    () async {
      final webRtc = await const UnavailableHivemindTransportBackend(
        HivemindTransportKind.webRtc,
        'not packaged',
      ).capability();
      final nsd = await const NsdTcpHivemindTransportBackend().capability();

      expect(nsd.available, isTrue);
      expect(nsd.contractVersion, 1);
      expect(webRtc.available, isFalse);
      expect(webRtc.backend, 'unavailable');
    },
  );

  test(
    'multiplexer routes one authenticated stream without packet theft',
    () async {
      final source = _MemoryPeerChannel('trusted-peer');
      final multiplexer = PeerChannelMultiplexer(source);
      final sync = multiplexer.channel(
        'sync',
        accepts: (packet) => packet['type'] == 'sync_start',
      );
      final hivemind = multiplexer.channel(
        'hivemind',
        accepts: (packet) => '${packet['type']}'.startsWith('hivemind_'),
      );
      final syncPackets = <Map<String, dynamic>>[];
      final hivemindPackets = <Map<String, dynamic>>[];
      final syncSub = sync.packets.listen(syncPackets.add);
      final hivemindSub = hivemind.packets.listen(hivemindPackets.add);

      source.receive({'type': 'hivemind_ping', 'nonce': 'one'});
      source.receive({'type': 'sync_start'});
      await Future<void>.delayed(Duration.zero);

      expect(hivemindPackets.single['nonce'], 'one');
      expect(syncPackets.single['type'], 'sync_start');
      await hivemind.send({'type': 'hivemind_pong'});
      expect(source.sent.single['type'], 'hivemind_pong');

      await multiplexer.close();
      await source.close();
      await syncSub.cancel();
      await hivemindSub.cancel();
    },
  );
}

final class _MemoryPeerChannel implements AuthenticatedPeerSyncChannel {
  _MemoryPeerChannel(this.peerId);

  @override
  final String peerId;
  final StreamController<Map<String, dynamic>> _packets =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> sent = [];

  @override
  Stream<Map<String, dynamic>> get packets => _packets.stream;

  @override
  Future<void> send(Map<String, dynamic> packet) async => sent.add(packet);

  void receive(Map<String, dynamic> packet) => _packets.add(packet);
  Future<void> close() => _packets.close();
}
