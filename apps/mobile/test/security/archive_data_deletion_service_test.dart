import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/archive_data_deletion_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_storage_sandbox.dart';

JournalEntry _sampleEntry() {
  return JournalEntry(
    id: 'e-delete-test',
    createdAt: DateTime.utc(2026, 6, 12, 10),
    transcript: 'I keep saying yes when I mean no.',
    durationSeconds: 12,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['boundaries'],
      exactLanguagePattern: 'yes when no',
      concreteObservation: 'Boundary pressure again.',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestStorageSandbox sandbox;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());

  test('deleteAllLocalArchive clears journal entries', () async {
    final journal = AppServices.instance.journalStore;
    await journal.save(_sampleEntry());

    expect(await journal.loadAll(), isNotEmpty);

    final result = await ArchiveDataDeletionService.deleteAllLocalArchive();

    expect(result.journalEntriesRemoved, 1);
    expect(result.derivedInsightsCleared, isTrue);
    expect(result.evidenceTrailsCleared, isTrue);
    expect(await journal.loadAll(), isEmpty);
  });
}