import 'package:archiveme_mobile/features/sync/journal_cloud_ledger_interceptor.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  JournalEntry entry(String transcript) {
    return JournalEntry(
      id: 'entry-1',
      createdAt: DateTime.utc(2026, 1, 2),
      transcript: transcript,
      durationSeconds: 8,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
  }

  CloudSyncService ledgerService({
    Future<void> Function(String entryId, String transcript, DateTime createdAt)?
    upload,
    Future<void> Function(String entryId)? remove,
    Future<List<JournalEntry>> Function()? loadEntries,
    Future<Set<String>> Function()? forgottenLabels,
    bool ledgerOptIn = true,
    bool consentSigned = true,
  }) {
    return CloudSyncService(
      isLedgerOptInEnabled: () async => ledgerOptIn,
      plainTextAiConsentSigned: () async => consentSigned,
      upload: upload,
      remove: remove,
      loadEntries: loadEntries,
      forgottenLabels: forgottenLabels,
    );
  }

  test('upload stays on the device while ledger opt-in is off', () async {
    final uploaded = <String>[];
    final service = ledgerService(
      ledgerOptIn: false,
      upload: (entryId, transcript, createdAt) async {
        uploaded.add('$entryId:$transcript');
      },
    );

    await service.uploadEntryToLedger(entry('I mentioned the river again.'));

    expect(uploaded, isEmpty);
  });

  test('upload stays on the device without plain-text consent', () async {
    final uploaded = <String>[];
    final service = ledgerService(
      consentSigned: false,
      upload: (entryId, transcript, createdAt) async {
        uploaded.add('$entryId:$transcript');
      },
    );

    await service.uploadEntryToLedger(entry('I mentioned the river again.'));

    expect(uploaded, isEmpty);
  });

  test('upload posts the transcript when ledger opt-in and consent hold', () async {
    final uploaded = <String>[];
    final service = ledgerService(
      upload: (entryId, transcript, createdAt) async {
        uploaded.add('$entryId:$transcript');
      },
    );

    await service.uploadEntryToLedger(entry('I mentioned the river again.'));

    expect(uploaded, ['entry-1:I mentioned the river again.']);
  });

  test('backfill sends each saved entry once the ledger is allowed', () async {
    final uploaded = <String>[];
    final service = ledgerService(
      loadEntries: () async => [
        entry('First morning by the river.'),
        entry('Second morning by the river.'),
      ],
      upload: (entryId, transcript, createdAt) async {
        uploaded.add(transcript);
      },
    );

    await service.backfill();

    expect(uploaded, [
      'First morning by the river.',
      'Second morning by the river.',
    ]);
  });

  test('a forgotten label is left out of the ledger copy', () async {
    final uploaded = <String>[];
    final service = ledgerService(
      forgottenLabels: () async => {'river'},
      upload: (entryId, transcript, createdAt) async {
        uploaded.add(transcript);
      },
    );

    await service.uploadEntryToLedger(entry('I mentioned the river again.'));

    expect(uploaded, ['I mentioned the again.']);
  });

  test('delete calls the server only when the ledger is allowed', () async {
    final removed = <String>[];
    final enabled = ledgerService(
      remove: (entryId) async {
        removed.add(entryId);
      },
    );
    await enabled.deleteEntryFromLedger('entry-1');

    final disabled = ledgerService(
      ledgerOptIn: false,
      remove: (entryId) async {
        removed.add('off-$entryId');
      },
    );
    await disabled.deleteEntryFromLedger('entry-1');

    expect(removed, ['entry-1']);
  });

  test('a local deletion deletes the ledger copy when ingest is allowed', () async {
    final removed = <String>[];
    final service = ledgerService(
      remove: (entryId) async {
        removed.add(entryId);
      },
    );
    await JournalCloudLedgerInterceptor(
      service: service,
      mayIngest: () async => true,
    ).onEntrySaved(entry('I mentioned the river again.').markDeleted());
    expect(removed, ['entry-1']);
  });

  test('the interceptor stays quiet when ledger consent is missing', () async {
    final removed = <String>[];
    final service = ledgerService(
      remove: (entryId) async {
        removed.add(entryId);
      },
    );
    await JournalCloudLedgerInterceptor(
      service: service,
      mayIngest: () async => false,
    ).onEntrySaved(entry('I mentioned the river again.').markDeleted());
    expect(removed, isEmpty);
  });
}
