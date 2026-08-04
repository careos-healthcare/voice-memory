import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/export_backup/vault_production_adapters.dart';

void main() {
  test(
    'production lifecycle quiesces, restarts, and resumes callbacks',
    () async {
      final events = <String>[];
      final lifecycle = ProductionVaultLifecycle(
        transcriptionPause: () async => events.add('pause'),
        transcriptionResume: () async => events.add('resume'),
        syncEngine: null,
        checkpointDatabases: () async => events.add('checkpoint'),
        closeStoresForRestore: () async => events.add('close'),
        reopenStoresAfterRestore: ({required succeeded}) async =>
            events.add('reopen:$succeeded'),
      );

      await lifecycle.quiesce();
      await lifecycle.prepareRestore();
      await lifecycle.finishRestore(succeeded: false);
      await lifecycle.resume();

      expect(events, [
        'pause',
        'checkpoint',
        'close',
        'reopen:false',
        'resume',
      ]);
    },
  );
}
