import 'dart:io';

import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_engine.dart';
import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_store.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_restore_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  required DateTime createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt,
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeRelatedEntries() => [
  _entry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

void main() {
  late Directory dir;
  late MobilePrefsStore prefs;

  setUp(() async {
    // Do not call AppServices.resetForTest. Exclusions are written to a
    // standalone prefs file so reload cannot cheat via the singleton.
    dir = Directory.systemTemp.createTempSync('exclusion_restore_race_');
    prefs = await MobilePrefsStore.open('${dir.path}/mobile_prefs.json');
    ArchiveExclusionStore.invalidateCache();
  });

  tearDown(() async {
    await prefs.drainPendingWrites();
    ArchiveExclusionStore.invalidateCache();
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test(
    'reloadArchiveStores keeps excluded evidence excluded when AppServices is down',
    () async {
      final entries = _threeRelatedEntries();
      final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
        entries,
      );
      expect(patternKey, isNotNull);

      await ArchiveExclusionStore(prefs).exclude(
        entryId: 'e3',
        patternKey: patternKey!,
      );
      expect(
        ArchiveExclusionStore.isExcluded(
          entryId: 'e3',
          patternKey: patternKey,
        ),
        isTrue,
      );

      // Exact post-restore sequence: wipe the process cache, then reload.
      // restoreBackup itself never reaches here when services are down —
      // this is reloadArchiveStores, the method the fail-open lived on.
      await LocalBackupRestoreService.reloadArchiveStores(prefs: prefs);

      expect(
        ArchiveExclusionStore.isExcluded(
          entryId: 'e3',
          patternKey: patternKey,
        ),
        isTrue,
      );
      expect(
        ArchiveExclusionEngine.isExcludedForActivePattern(
          entryId: 'e3',
          entries: entries,
        ),
        isTrue,
      );
      expect(
        ArchiveExclusionEngine.eligibleForActivePattern(
          entries,
        ).map((entry) => entry.id),
        isNot(contains('e3')),
      );
    },
  );
}
