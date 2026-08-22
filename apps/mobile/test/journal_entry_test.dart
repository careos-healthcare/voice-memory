import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

Reflection _reflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

JournalEntry _fullEntry() => JournalEntry(
  id: 'entry-1',
  createdAt: DateTime.utc(2026),
  transcript: 'hello',
  durationSeconds: 10,
  reflection: _reflection(),
  syncStatus: SyncStatus.pendingUpload,
  localAudioPath: '/tmp/vm_rec_a.m4a',
  treatAsNew: true,
  connectionApproved: true,
  keepExactDetails: true,
  keepSeparate: true,
  archiveThreadId: 'thread-1',
  archivePackId: 'pack-1',
  isPinned: true,
  pinnedAt: DateTime.utc(2026, 1, 2),
  isArchived: true,
  archivedAt: DateTime.utc(2026, 1, 3),
  entryAboutness: 'about_someone_else',
  memorySurfacing: 'reduced',
  preserveOriginal: true,
  captureContextTag: 'tag-1',
  biomarkers: const CognitiveBiomarkers(
    lexicalDiversity: 0.1,
    cohesionDrift: 0.2,
    emotionalVolatility: 0.3,
  ),
  parentHookId: 'hook-1',
  wasGrounded: true,
  ownerKey: 'owner-1',
  updatedAt: DateTime.utc(2026, 1, 4),
  revision: 3,
  changeId: 'change-1',
);

void main() {
  group('JournalEntry construction defaults (new entries)', () {
    test(
      'defaults updatedAt to createdAt, revision to 1, schemaVersion to current',
      () {
        final entry = JournalEntry(
          id: 'x',
          createdAt: DateTime.utc(2026),
          transcript: 't',
          durationSeconds: 1,
          reflection: _reflection(),
        );
        expect(entry.updatedAt, entry.createdAt);
        expect(entry.revision, 1);
        expect(entry.changeId, isNotEmpty);
        expect(entry.schemaVersion, JournalEntry.currentSchemaVersion);
        expect(entry.deletedAt, isNull);
        expect(entry.isDeleted, isFalse);
      },
    );

    test('rejects a non-positive revision by clamping to 1', () {
      final entry = JournalEntry(
        id: 'x',
        createdAt: DateTime.utc(2026),
        transcript: 't',
        durationSeconds: 1,
        reflection: _reflection(),
        revision: 0,
      );
      expect(entry.revision, 1);
    });

    test(
      'two freshly-constructed entries with different ids get different changeIds',
      () {
        final a = JournalEntry(
          id: 'a',
          createdAt: DateTime.utc(2026),
          transcript: 't',
          durationSeconds: 1,
          reflection: _reflection(),
        );
        final b = JournalEntry(
          id: 'b',
          createdAt: DateTime.utc(2026),
          transcript: 't',
          durationSeconds: 1,
          reflection: _reflection(),
        );
        expect(a.changeId, isNot(b.changeId));
      },
    );
  });

  group('JournalEntry.copyWith losslessness', () {
    test('omitting every argument preserves every field exactly', () {
      final entry = _fullEntry();
      final copy = entry.copyWith();
      expect(copy.toJson(), entry.toJson());
    });

    test('changing one field leaves every other field untouched', () {
      final entry = _fullEntry();
      final copy = entry.copyWith(transcript: 'updated transcript');
      final beforeJson = entry.toJson();
      final afterJson = copy.toJson();
      expect(afterJson['transcript'], 'updated transcript');
      final expected = Map<String, dynamic>.from(beforeJson)
        ..['transcript'] = 'updated transcript';
      expect(afterJson, expected);
    });

    test(
      'omitting a nullable field argument preserves its existing non-null value',
      () {
        final entry = _fullEntry();
        final copy = entry.copyWith(transcript: 'x');
        expect(copy.localAudioPath, entry.localAudioPath);
        expect(copy.archiveThreadId, entry.archiveThreadId);
        expect(copy.archivePackId, entry.archivePackId);
        expect(copy.pinnedAt, entry.pinnedAt);
        expect(copy.archivedAt, entry.archivedAt);
        expect(copy.captureContextTag, entry.captureContextTag);
        expect(copy.biomarkers, entry.biomarkers);
        expect(copy.parentHookId, entry.parentHookId);
        expect(copy.verifiedProof, entry.verifiedProof);
        expect(copy.ownerKey, entry.ownerKey);
        expect(copy.deletedAt, entry.deletedAt);
      },
    );

    test(
      'explicitly passing null clears a nullable field without disturbing others',
      () {
        final entry = _fullEntry();

        expect(entry.copyWith(localAudioPath: null).localAudioPath, isNull);
        expect(entry.copyWith(archiveThreadId: null).archiveThreadId, isNull);
        expect(entry.copyWith(archivePackId: null).archivePackId, isNull);
        expect(entry.copyWith(pinnedAt: null).pinnedAt, isNull);
        expect(entry.copyWith(archivedAt: null).archivedAt, isNull);
        expect(
          entry.copyWith(captureContextTag: null).captureContextTag,
          isNull,
        );
        expect(entry.copyWith(biomarkers: null).biomarkers, isNull);
        expect(entry.copyWith(parentHookId: null).parentHookId, isNull);
        expect(entry.copyWith(verifiedProof: null).verifiedProof, isNull);
        expect(entry.copyWith(ownerKey: null).ownerKey, isNull);
        expect(entry.copyWith(deletedAt: null).deletedAt, isNull);

        // Clearing one field must not disturb any other field.
        final cleared = entry.copyWith(localAudioPath: null);
        final expectedJson = Map<String, dynamic>.from(entry.toJson())
          ..remove('localAudioPath');
        expect(cleared.toJson(), expectedJson);
      },
    );

    test('clearLocalAudioPath is a dedicated, lossless clear operation', () {
      final entry = _fullEntry();
      final cleared = entry.clearLocalAudioPath();
      expect(cleared.localAudioPath, isNull);
      final expectedJson = Map<String, dynamic>.from(entry.toJson())
        ..remove('localAudioPath');
      expect(cleared.toJson(), expectedJson);
    });
  });

  group('legacy migration (fromJson)', () {
    Map<String, dynamic> legacyJson() => {
      'id': 'legacy-1',
      'createdAt': DateTime.utc(2025, 3).toIso8601String(),
      'transcript': 'legacy entry',
      'durationSeconds': 5,
      'reflection': _reflection().toJson(),
      '_syncStatus': 'synced',
      // Deliberately no updatedAt/revision/changeId/deletedAt/schemaVersion —
      // this is what every pre-P1 persisted entry looks like on disk.
    };

    test('legacy updatedAt defaults to createdAt', () {
      final entry = JournalEntry.fromJson(legacyJson());
      expect(entry.updatedAt, entry.createdAt);
    });

    test('legacy revision starts at 1', () {
      final entry = JournalEntry.fromJson(legacyJson());
      expect(entry.revision, 1);
    });

    test('legacy changeId is generated deterministically', () {
      final a = JournalEntry.fromJson(legacyJson());
      final b = JournalEntry.fromJson(legacyJson());
      expect(a.changeId, isNotEmpty);
      expect(a.changeId, b.changeId);
    });

    test(
      'migration is idempotent: migrating an already-migrated JSON twice is a no-op',
      () {
        final once = JournalEntry.fromJson(legacyJson());
        final migratedJson = once.toJson();
        final twice = JournalEntry.fromJson(migratedJson);
        expect(twice.toJson(), migratedJson);
        expect(twice.changeId, once.changeId);
        expect(twice.revision, once.revision);
        expect(twice.updatedAt, once.updatedAt);
      },
    );

    test(
      'never silently discards a legacy entry: all legacy fields survive',
      () {
        final json = legacyJson();
        final entry = JournalEntry.fromJson(json);
        expect(entry.id, 'legacy-1');
        expect(entry.transcript, 'legacy entry');
        expect(entry.durationSeconds, 5);
        expect(entry.syncStatus, SyncStatus.synced);
      },
    );

    test('round-trips new sync fields through toJson/fromJson', () {
      final entry = _fullEntry();
      final restored = JournalEntry.fromJson(entry.toJson());
      expect(restored.toJson(), entry.toJson());
    });

    test('fromJson reports recoverable data issues via onDataIssue', () {
      final issues = <String>[];
      final entry = JournalEntry.fromJson(
        {
          'id': '',
          'transcript': 'hello',
          'durationSeconds': 1,
          'reflection': _reflection().toJson(),
        },
        onDataIssue: ({required entryId, required issue}) {
          issues.add(issue);
        },
      );
      expect(issues, contains('missing_or_empty_id'));
      expect(issues, contains('missing_created_at'));
      expect(entry.id, isEmpty);
      expect(entry.transcript, 'hello');
    });
  });

  group('JournalEntry value equality', () {
    test('equal entries compare equal and share hashCode', () {
      final a = _fullEntry();
      final b = JournalEntry.fromJson(a.toJson());
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('changing any field breaks equality', () {
      final base = _fullEntry();
      expect(base.copyWith(transcript: 'changed'), isNot(equals(base)));
      expect(base.copyWith(revision: base.revision + 1), isNot(equals(base)));
      expect(
        base.copyWith(captureContextTag: 'other-tag'),
        isNot(equals(base)),
      );
    });

    test('toString omits full transcript body', () {
      final entry = _fullEntry();
      expect(entry.toString(), isNot(contains(entry.transcript)));
      expect(entry.toString(), contains('transcriptLength:'));
      expect(entry.toString(), contains(entry.id));
    });
  });

  group('markEdited / markDeleted changeIdGenerator', () {
    test('markEdited accepts injected now and changeIdGenerator', () {
      final entry = _fullEntry();
      final fixedNow = DateTime.utc(2026, 7, 1);
      const fixedChangeId = 'fixed-change-id';

      final edited = entry.markEdited(
        now: () => fixedNow,
        changeIdGenerator: () => fixedChangeId,
      );

      expect(edited.updatedAt, fixedNow);
      expect(edited.changeId, fixedChangeId);
      expect(edited.revision, entry.revision + 1);
    });

    test('markDeleted accepts injected changeIdGenerator', () {
      final entry = _fullEntry();
      const fixedChangeId = 'deleted-change-id';

      final deleted = entry.markDeleted(
        now: () => DateTime.utc(2026, 7, 2),
        changeIdGenerator: () => fixedChangeId,
      );

      expect(deleted.changeId, fixedChangeId);
      expect(deleted.isDeleted, isTrue);
    });
  });

  group('markEdited / markSyncAcknowledged / markDeleted', () {
    test(
      'markEdited bumps revision, refreshes updatedAt, and generates a new changeId',
      () {
        final entry = _fullEntry();
        final later = DateTime.utc(2026, 5, 5);
        final edited = entry.markEdited(now: () => later);
        expect(edited.revision, entry.revision + 1);
        expect(edited.updatedAt, later);
        expect(edited.changeId, isNot(entry.changeId));
        // Content untouched.
        expect(edited.transcript, entry.transcript);
        expect(edited.biomarkers, entry.biomarkers);
      },
    );

    test(
      'markSyncAcknowledged changes only syncStatus — never looks like a customer edit',
      () {
        final entry = _fullEntry();
        final acked = entry.markSyncAcknowledged();
        expect(acked.syncStatus, SyncStatus.synced);
        expect(acked.updatedAt, entry.updatedAt);
        expect(acked.revision, entry.revision);
        expect(acked.changeId, entry.changeId);
        final expectedJson = Map<String, dynamic>.from(entry.toJson())
          ..['_syncStatus'] = 'synced';
        expect(acked.toJson(), expectedJson);
      },
    );

    test(
      'markDeleted creates a tombstone: sets deletedAt, bumps revision/updatedAt/changeId, queues for sync',
      () {
        final entry = _fullEntry();
        final now = DateTime.utc(2026, 6);
        final deleted = entry.markDeleted(now: () => now);
        expect(deleted.isDeleted, isTrue);
        expect(deleted.deletedAt, now);
        expect(deleted.updatedAt, now);
        expect(deleted.revision, entry.revision + 1);
        expect(deleted.changeId, isNot(entry.changeId));
        expect(deleted.syncStatus, SyncStatus.pendingUpload);
        // A tombstone still carries every other field — a hard purge is a
        // different, separate operation (JournalStore.clearAll / account
        // deletion), not this one.
        expect(deleted.transcript, entry.transcript);
        expect(deleted.ownerKey, entry.ownerKey);
      },
    );
  });

  group('JournalSyncCompare — shared mobile/server conflict ordering', () {
    JournalEntry base() => JournalEntry(
      id: 'e',
      createdAt: DateTime.utc(2026),
      transcript: 't',
      durationSeconds: 1,
      reflection: _reflection(),
      updatedAt: DateTime.utc(2026),
      revision: 1,
      changeId: 'aaa',
    );

    test('higher revision wins regardless of updatedAt', () {
      final low = base().copyWith(
        revision: 1,
        updatedAt: DateTime.utc(2026, 2),
      );
      final high = base().copyWith(
        revision: 2,
        updatedAt: DateTime.utc(2026),
      );
      expect(JournalSyncCompare.winner(low, high), same(high));
      expect(JournalSyncCompare.winner(high, low), same(high));
    });

    test('equal revision: later updatedAt wins', () {
      final earlier = base().copyWith(updatedAt: DateTime.utc(2026));
      final later = base().copyWith(updatedAt: DateTime.utc(2026, 1, 2));
      expect(JournalSyncCompare.winner(earlier, later), same(later));
    });

    test('equal revision and updatedAt: deterministic changeId tie-break', () {
      final ts = DateTime.utc(2026);
      final a = base().copyWith(updatedAt: ts, changeId: 'aaa');
      final b = base().copyWith(updatedAt: ts, changeId: 'zzz');
      expect(JournalSyncCompare.winner(a, b), same(b));
      expect(JournalSyncCompare.winner(b, a), same(b));
    });

    test('identical entries compare equal (0)', () {
      final a = base();
      final b = base();
      expect(JournalSyncCompare.compare(a, b), 0);
    });
  });
}