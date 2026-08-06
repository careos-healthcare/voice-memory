import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_evidence_index.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';

void main() {
  ProofSourceEntry entry(
    String id,
    String transcript, {
    String archive = 'archive_a',
    String owner = 'owner_a',
    DateTime? createdAt,
    bool deleted = false,
    bool archived = false,
    String? revision,
  }) => ProofSourceEntry(
    entryId: id,
    archiveScope: archive,
    ownerScope: owner,
    transcript: transcript,
    transcriptRevision: revision ?? 'rev_${transcript.length}',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    sourceType: ProofSourceType.userTyped,
    deleted: deleted,
    archived: archived,
  );

  ArchiveEvidenceIndex freshIndex() =>
      ArchiveEvidenceIndex(archiveScope: 'archive_a', ownerScope: 'owner_a');

  group('related sources', () {
    test('finds the moment that shares a subject', () {
      final index = freshIndex();
      index.upsertEntry(
        entry('a', 'I keep checking my phone during dinner with family'),
      );
      index.upsertEntry(
        entry('b', 'Checked my phone all through dinner again tonight'),
      );
      index.upsertEntry(entry('c', 'The car needs new tyres before winter'));

      expect(index.relatedSources('a'), contains('b'));
      expect(index.relatedSources('a'), isNot(contains('c')));
    });

    test('an unrelated archive contributes nothing', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'I keep checking my phone during dinner'));
      index.upsertEntry(
        entry(
          'other',
          'I keep checking my phone during dinner',
          archive: 'archive_b',
        ),
      );

      expect(index.relatedSources('a'), isEmpty);
    });

    test('a different owner is never indexed', () {
      final index = freshIndex();
      index.upsertEntry(
        entry('theirs', 'checking my phone at dinner', owner: 'owner_b'),
      );

      expect(index.sources, isEmpty);
    });

    test('deleted and archived moments stop seeding new evidence', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'checking my phone during dinner again'));
      index.upsertEntry(
        entry('deleted', 'checking my phone during dinner', deleted: true),
      );
      index.upsertEntry(
        entry('archived', 'checking my phone during dinner', archived: true),
      );

      expect(index.relatedSources('a'), isEmpty);
    });

    test('the earlier moment wins an equal overlap', () {
      final index = freshIndex();
      const shared = 'checking my phone during dinner';
      index.upsertEntry(entry('subject', shared));
      index.upsertEntry(
        entry('later', shared, createdAt: DateTime(2026, 3, 1)),
      );
      index.upsertEntry(
        entry('earlier', shared, createdAt: DateTime(2026, 2, 1)),
      );

      expect(index.relatedSources('subject').first, 'earlier');
    });

    test('an unknown entry has no related sources', () {
      expect(freshIndex().relatedSources('nope'), isEmpty);
    });
  });

  group('staleness', () {
    test('an edited transcript is stale until reindexed', () {
      final index = freshIndex();
      final original = entry('a', 'checking my phone', revision: 'rev_1');
      index.upsertEntry(original);
      expect(index.isStale(original), isFalse);

      final edited = entry('a', 'checking my phone less', revision: 'rev_2');
      expect(index.isStale(edited), isTrue);

      index.upsertEntry(edited);
      expect(index.isStale(edited), isFalse);
    });

    test('an unindexed entry counts as stale', () {
      expect(freshIndex().isStale(entry('missing', 'anything')), isTrue);
    });
  });

  group('occurrences', () {
    test('counts distinct moments, not citations', () {
      final index = freshIndex();
      index.upsertEntry(
        entry('a', 'phone at dinner', createdAt: DateTime(2026, 1, 1)),
      );
      index.upsertEntry(
        entry('b', 'phone at dinner', createdAt: DateTime(2026, 2, 1)),
      );

      index.recordFraming(
        framing: 'framing_1',
        claimKind: 'repeated',
        supportingEntryIds: ['a', 'b', 'a'],
      );

      final occurrences = index.occurrences('framing_1')!;
      expect(occurrences.occurrenceCount, 2);
      expect(occurrences.firstOccurrence, DateTime(2026, 1, 1));
      expect(occurrences.latestOccurrence, DateTime(2026, 2, 1));
    });

    test('a window counts only what is logged inside it', () {
      final index = freshIndex();
      final now = DateTime(2026, 3, 1);
      index.upsertEntry(
        entry('recent', 'phone at dinner', createdAt: DateTime(2026, 2, 20)),
      );
      index.upsertEntry(
        entry('old', 'phone at dinner', createdAt: DateTime(2025, 6, 1)),
      );
      index.recordFraming(
        framing: 'framing_1',
        claimKind: 'repeated',
        supportingEntryIds: ['recent', 'old'],
      );

      final occurrences = index.occurrences('framing_1')!;
      expect(occurrences.countWithin(const Duration(days: 30), now: now), 1);
      expect(occurrences.countWithin(const Duration(days: 400), now: now), 2);
    });

    test('an unusable source never supports a framing', () {
      final index = freshIndex();
      index.upsertEntry(entry('gone', 'phone at dinner', deleted: true));
      index.recordFraming(
        framing: 'framing_1',
        claimKind: 'repeated',
        supportingEntryIds: ['gone'],
      );

      expect(index.occurrences('framing_1')!.occurrenceCount, 0);
    });

    test('removing an entry withdraws its support', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'phone at dinner'));
      index.upsertEntry(entry('b', 'phone at dinner tonight'));
      index.recordFraming(
        framing: 'framing_1',
        claimKind: 'repeated',
        supportingEntryIds: ['a', 'b'],
      );

      index.removeEntry('a');

      expect(index.occurrences('framing_1')!.occurrenceCount, 1);
      expect(index.integrityCheck(), isEmpty);
    });
  });

  group('persistence', () {
    test('survives a round trip', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'checking my phone during dinner'));
      index.upsertEntry(entry('b', 'checked my phone at dinner again'));
      index.recordFraming(
        framing: 'framing_1',
        claimKind: 'repeated',
        supportingEntryIds: ['a', 'b'],
        contradictionEntryIds: ['b'],
      );

      final restored = ArchiveEvidenceIndex.fromJson(
        jsonDecode(jsonEncode(index.toJson())) as Map<String, dynamic>,
        archiveScope: 'archive_a',
        ownerScope: 'owner_a',
      )!;

      expect(restored.relatedSources('a'), contains('b'));
      expect(restored.occurrences('framing_1')!.occurrenceCount, 2);
      expect(
        restored.occurrences('framing_1')!.contradictionEntryIds,
        contains('b'),
      );
    });

    test('refuses a payload from another archive', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'checking my phone'));

      expect(
        ArchiveEvidenceIndex.fromJson(
          index.toJson(),
          archiveScope: 'archive_b',
          ownerScope: 'owner_a',
        ),
        isNull,
      );
    });

    test('refuses a payload from another owner', () {
      final index = freshIndex();
      expect(
        ArchiveEvidenceIndex.fromJson(
          index.toJson(),
          archiveScope: 'archive_a',
          ownerScope: 'owner_b',
        ),
        isNull,
      );
    });

    test('refuses a schema it does not understand', () {
      final payload = freshIndex().toJson()
        ..['schemaVersion'] = ArchiveEvidenceIndex.schemaVersion + 1;

      expect(
        ArchiveEvidenceIndex.fromJson(
          payload,
          archiveScope: 'archive_a',
          ownerScope: 'owner_a',
        ),
        isNull,
      );
    });

    test('a corrupt payload reads as null rather than half an archive', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'checking my phone'));
      final payload = index.toJson()
        ..['sources'] = [
          {'entryId': 'a', 'createdAt': 'not-a-date'},
        ];

      expect(
        ArchiveEvidenceIndex.fromJson(
          payload,
          archiveScope: 'archive_a',
          ownerScope: 'owner_a',
        ),
        isNull,
      );
    });

    test('the same word digests differently per archive', () {
      final first = ArchiveEvidenceIndex(
        archiveScope: 'archive_a',
        ownerScope: 'owner_a',
      )..upsertEntry(entry('a', 'checking my phone during dinner'));
      final second =
          ArchiveEvidenceIndex(
            archiveScope: 'archive_b',
            ownerScope: 'owner_a',
          )..upsertEntry(
            entry('a', 'checking my phone during dinner', archive: 'archive_b'),
          );

      expect(
        first.sources.single.terms.intersection(second.sources.single.terms),
        isEmpty,
      );
    });

    test('stores no raw transcript text', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'checking my phone during dinner'));
      final encoded = jsonEncode(index.toJson());

      for (final word in ['checking', 'phone', 'dinner']) {
        expect(encoded, isNot(contains(word)));
      }
    });
  });

  group('integrity', () {
    test('reports a restored framing citing a source that is gone', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'phone at dinner'));
      index.upsertEntry(entry('b', 'phone at dinner again'));
      index.recordFraming(
        framing: 'framing_1',
        claimKind: 'repeated',
        supportingEntryIds: ['a', 'b'],
      );

      // Mimics a persisted file whose sources were pruned but whose framings
      // were not — the corruption the check exists to catch.
      final payload = index.toJson();
      payload['sources'] = (payload['sources'] as List)
          .where((source) => (source as Map)['entryId'] == 'a')
          .toList();

      final restored = ArchiveEvidenceIndex.fromJson(
        payload,
        archiveScope: 'archive_a',
        ownerScope: 'owner_a',
      )!;

      expect(
        restored.integrityCheck(),
        contains(contains('cites unknown source b')),
      );
    });

    test('a healthy index reports nothing', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'phone at dinner'));
      index.recordFraming(
        framing: 'framing_1',
        claimKind: 'repeated',
        supportingEntryIds: ['a'],
      );

      expect(index.integrityCheck(), isEmpty);
    });

    test('a rebuild restores a clean index', () {
      final index = freshIndex();
      index.upsertEntry(entry('a', 'phone at dinner'));
      index.rebuild([
        entry('x', 'walking the dog every morning'),
        entry('y', 'walked the dog again this morning'),
      ]);

      expect(index.sources.map((source) => source.entryId), ['x', 'y']);
      expect(index.relatedSources('x'), contains('y'));
      expect(index.integrityCheck(), isEmpty);
    });
  });
}
