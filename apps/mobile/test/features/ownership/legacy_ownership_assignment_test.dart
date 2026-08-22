import 'dart:io';

import 'package:archiveme_mobile/features/ownership/legacy_ownership_assignment_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

void main() {
  test(
    'legacy assignment is idempotent and does not duplicate entries',
    () async {
      final dir = await Directory.systemTemp.createTemp('legacy_owner_');
      final recovery = await JournalStore.open(
        '${dir.path}/recovery.json',
        encryptAtRest: false,
      );
      final accountA = await JournalStore.open(
        '${dir.path}/account_a.json',
        encryptAtRest: false,
      );
      final accountB = await JournalStore.open(
        '${dir.path}/account_b.json',
        encryptAtRest: false,
      );
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');

      await recovery.save(
        JournalEntry(
          id: 'legacy-1',
          createdAt: DateTime.utc(2026),
          transcript: 'unowned entry',
          durationSeconds: 1,
          reflection: _reflection(),
        ),
      );

      final serviceA = LegacyOwnershipAssignmentService(
        recoveryJournal: recovery,
        activeJournal: accountA,
        prefs: prefs,
      );
      expect(await serviceA.countAwaitingAssignment(), 1);

      final first = await serviceA.assignAllToAccount('user-a');
      expect(first.importedCount, 1);
      expect(await accountA.loadAll(), hasLength(1));
      expect(await accountB.loadAll(), isEmpty);

      final second = await serviceA.assignAllToAccount('user-a');
      expect(second.importedCount, 0);

      final serviceB = LegacyOwnershipAssignmentService(
        recoveryJournal: recovery,
        activeJournal: accountB,
        prefs: prefs,
      );
      final blocked = await serviceB.assignAllToAccount('user-b');
      expect(blocked.importedCount, 0);
      expect(await accountB.loadAll(), isEmpty);
    },
  );
}