import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2025, 5, int.parse(id) + 1),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: 'pattern',
      concreteObservation: '',
      repeatedSignal: 'signal',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  test('isIntentionalEmptyArchive true for zero entries', () {
    expect(isIntentionalEmptyArchive([]), isTrue);
  });

  test('isIntentionalEmptyArchive true when no eligible evidence', () {
    final short = List.generate(3, (i) => _entry('$i', 'too short'));
    expect(ArchiveEvidenceGuard.eligibleReflectionCount(short), 0);
    expect(isIntentionalEmptyArchive(short), isTrue);
  });

  test('intentional empty copy matches current patterns-empty spec', () {
    expect(
      EmptyArchiveCopy.intentionalEmptyTitle,
      ConsumerUiCopy.patternsEmptyPageTitle,
    );
    expect(
      EmptyArchiveCopy.intentionalEmptyOpening,
      ConsumerUiCopy.patternsEarlyStateBody,
    );
    expect(EmptyArchiveCopy.recordThoughtCta, ConsumerUiCopy.patternsEmptyCta);
    expect(EmptyArchiveCopy.typeInsteadCta, 'Type instead');

    final label = IntentionalEmptyArchiveContent.semanticsLabel;
    expect(label, contains(EmptyArchiveCopy.intentionalEmptyTitle));
    expect(label, contains(EmptyArchiveCopy.intentionalEmptyOpening));
    expect(label, isNot(contains('Your archive is empty')));
    expect(label, isNot(contains('VoiceMemory')));
  });

  test('intentional empty extended copy is ArchiveMe-safe', () {
    expect(EmptyArchiveCopy.intentionalEmptyLongTermRecord, isNotEmpty);
    expect(EmptyArchiveCopy.intentionalEmptyPatternsOverTime, isNotEmpty);
    expect(EmptyArchiveCopy.intentionalEmptyFutureIntro, isNotEmpty);
    expect(EmptyArchiveCopy.intentionalEmptyFutureQuotes, hasLength(4));
    expect(EmptyArchiveCopy.intentionalEmptyClosing, isNotEmpty);
    expect(
      EmptyArchiveCopy.intentionalEmptyLongTermRecord,
      isNot(contains('I want freedom')),
    );
  });

  test('isIntentionalEmptyArchive false with eligible reflections', () {
    final entries = List.generate(
      5,
      (i) => _entry(
        '$i',
        'This is a long enough transcript to count as archive evidence.',
      ),
    );
    expect(isIntentionalEmptyArchive(entries), isFalse);
  });
}
