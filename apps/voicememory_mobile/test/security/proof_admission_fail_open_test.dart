import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture guard — production lib must not fail-open remote processing consent.
void main() {
  test('ProofSourceEntry and ProofAdmissionCache default remoteProcessingConsented to false', () {
    final models = File('lib/features/proof_admission/proof_admission_models.dart')
        .readAsStringSync();
    final cache = File('lib/features/proof_admission/proof_admission_cache.dart')
        .readAsStringSync();

    expect(
      models,
      contains('remoteProcessingConsented = false'),
      reason: 'ProofSourceEntry must opt-in, not default true',
    );
    expect(
      cache,
      isNot(contains('remoteProcessingConsented = true')),
      reason: 'ProofAdmissionCache must not default consent to true',
    );
    expect(
      cache,
      contains('remoteProcessingConsented = false'),
    );
  });

  test('capture pipeline saveRecoveredVaultEntry requires explicit consent param', () {
    final pipeline = File('lib/services/capture_pipeline_service.dart').readAsStringSync();
    expect(pipeline, contains('required bool remoteProcessingConsented'));
    expect(
      pipeline,
      isNot(contains('remoteProcessingConsented: true')),
      reason: 'recovered vault entries must not hardcode consent',
    );
  });

  test('SyncService production path uses encrypted coordinator only', () {
    final sync = File('lib/services/sync_service.dart').readAsStringSync();
    expect(sync, contains('_encryptedCoordinator.syncNow()'));
    expect(sync, isNot(contains('createJournalEntry(')));
    expect(sync, isNot(contains('listJournal(')));
  });
}
