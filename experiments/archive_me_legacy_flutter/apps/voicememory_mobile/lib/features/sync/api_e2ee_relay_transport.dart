import '../../api/journal_sync_api_client.dart';
import 'e2ee_sync_models.dart';
import 'encrypted_sync_engine.dart';

class ApiE2EERelayTransport implements E2EERelayTransport {
  const ApiE2EERelayTransport(this.client);

  final JournalSyncApiClient client;

  @override
  Future<void> push(E2EESyncEnvelope envelope) => client.syncPush({
    'blobs': [envelope.toRelayBlob()],
  });

  @override
  Future<List<E2EESyncEnvelope>> pull() async {
    final snapshot = await client.syncPull();
    return snapshot.blobs
        .where((blob) => blob['type'] == 'crdt_operations')
        .map(E2EESyncEnvelope.fromRelayBlob)
        .toList(growable: false);
  }
}
