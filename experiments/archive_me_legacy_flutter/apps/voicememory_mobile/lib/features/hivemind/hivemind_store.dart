import '../../storage/encrypted_json_file_store.dart';
import 'hivemind_models.dart';

final class HivemindStore {
  const HivemindStore(this.storage);

  final EncryptedJsonFileStore storage;

  Future<HivemindGovernance> governance() async {
    final raw = await storage.readJson();
    if (raw is! Map || raw['governance'] is! Map) {
      return const HivemindGovernance();
    }
    return HivemindGovernance.fromJson(
      Map<String, dynamic>.from(raw['governance'] as Map),
    );
  }

  Future<void> writeGovernance(HivemindGovernance governance) => storage
      .writeJson({'schemaVersion': 1, 'governance': governance.toJson()});

  Future<void> clear() => storage.writeJson(const <String, dynamic>{});
}
