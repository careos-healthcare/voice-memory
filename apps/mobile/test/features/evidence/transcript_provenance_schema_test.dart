import 'dart:convert';

import 'package:archiveme_mobile/features/belief_evidence/evidence/journal_transcript_evidence_indexer.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/legacy_transcript_registry.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_notice.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_journal_snapshot.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_builder.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_model.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/sync/journal_conflict_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _spoken =
    'I said yes to the extra project even though I am already stretched.';

const _reflectionObservation =
    'You tend to say yes before checking your capacity.';

Reflection _reflection() => const Reflection(
  mood: 'tired',
  emotionalIntensity: 3,
  recurringThemes: ['work'],
  exactLanguagePattern: 'I keep overcommitting to people at work.',
  concreteObservation: _reflectionObservation,
  repeatedSignal: 'overcommitment',
);

JournalEntry _entry({
  String id = 'entry-1',
  String transcript = _spoken,
  TranscriptProvenance? provenance,
  int revision = 1,
  DateTime? updatedAt,
}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 6, 1),
  transcript: transcript,
  durationSeconds: 42,
  reflection: _reflection(),
  transcriptProvenance: provenance ?? TranscriptProvenance.unknownLegacy,
  revision: revision,
  updatedAt: updatedAt ?? DateTime.utc(2026, 6, 1),
  changeId: 'change-$id-$revision',
);

void main() {
  setUp(() {
    TranscriptEvidenceIndex.resetForTest();
    LegacyTranscriptRegistry.resetForTest();
  });
  tearDown(() {
    TranscriptEvidenceIndex.resetForTest();
    LegacyTranscriptRegistry.resetForTest();
  });

  group('an absent provenance never reads back as trusted', () {
    test('a payload written before the field existed decodes as legacy', () {
      final legacyPayload = {
        'id': 'entry-legacy',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'transcript': _spoken,
        'durationSeconds': 42,
        'reflection': _reflection().toJson(),
      };

      final decoded = JournalEntry.fromJson(legacyPayload);

      expect(decoded.transcriptProvenance, TranscriptProvenance.unknownLegacy);
      expect(decoded.transcriptProvenance.isQuotable, isFalse);
    });

    test('an explicit null and an empty string are both legacy', () {
      for (final raw in [null, '']) {
        final decoded = JournalEntry.fromJson({
          'id': 'entry-null',
          'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          'transcript': _spoken,
          'durationSeconds': 42,
          'reflection': _reflection().toJson(),
          'transcriptProvenance': raw,
        });
        expect(decoded.transcriptProvenance, TranscriptProvenance.unknownLegacy);
      }
    });

    test('an unrecognised value from a newer build is legacy, not trusted', () {
      // A future member this build has never heard of must not be guessed at.
      expect(
        TranscriptProvenance.fromStorage('on_device_whisper_v3'),
        TranscriptProvenance.unknownLegacy,
      );
      expect(TranscriptProvenance.fromStorage('final'), TranscriptProvenance.unknownLegacy);
      expect(TranscriptProvenance.fromStorage(''), TranscriptProvenance.unknownLegacy);
    });

    test('the constructor default is the untrusted value', () {
      final withoutStamp = JournalEntry(
        id: 'e',
        createdAt: DateTime.utc(2026, 1, 1),
        transcript: _spoken,
        durationSeconds: 1,
        reflection: _reflection(),
      );

      expect(
        withoutStamp.transcriptProvenance,
        TranscriptProvenance.unknownLegacy,
      );
      expect(withoutStamp.copyWith().transcriptProvenance,
          TranscriptProvenance.unknownLegacy);
    });
  });

  group('serialization writes the field every time', () {
    test('toJson emits it even when it equals the default', () {
      final json = _entry(provenance: TranscriptProvenance.unknownLegacy).toJson();

      expect(json.containsKey('transcriptProvenance'), isTrue);
      expect(json['transcriptProvenance'], 'unknown_legacy');
    });

    test('every member survives a JSON round-trip', () {
      for (final provenance in TranscriptProvenance.values) {
        final json = _entry(provenance: provenance).toJson();
        final decoded = JournalEntry.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map),
        );
        expect(decoded.transcriptProvenance, provenance);
      }
    });

    test('the residual payload stored in SQLite carries it', () {
      // `toResidualJson` drops keys held in dedicated columns. Provenance has
      // no column, so it has to survive here or it is lost on every local write.
      final residual = _entry(
        provenance: TranscriptProvenance.speechToText,
      ).toResidualJson();

      expect(residual['transcriptProvenance'], 'speech_to_text');
    });
  });

  group('the evidence index refuses legacy text', () {
    test('a legacy entry registers no source at all', () {
      final legacy = _entry(provenance: TranscriptProvenance.unknownLegacy);

      // The text itself is perfectly mintable — long enough, not a placeholder
      // — so the provenance check is the only thing keeping it out of the
      // index. Without it this entry would be quotable, which is the state the
      // existing archive is in today.
      expect(
        SpokenTranscript.fromCaptureText(
          entryId: legacy.id,
          transcript: legacy.transcript,
        ),
        isNotNull,
      );

      JournalTranscriptEvidenceIndexer.rememberEntry(legacy);

      expect(TranscriptEvidenceIndex.hasSource('entry-1'), isFalse);
      expect(TranscriptEvidenceIndex.sourceCount, 0);
    });

    test('speech-to-text and user-edited text are both indexed', () {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(id: 'stt', provenance: TranscriptProvenance.speechToText),
      );
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(id: 'edited', provenance: TranscriptProvenance.userEdited),
      );

      expect(TranscriptEvidenceIndex.transcriptFor('stt'), _spoken);
      expect(TranscriptEvidenceIndex.transcriptFor('edited'), _spoken);
    });

    test('provenance is checked before the text is', () {
      // Same characters, different provenance: only the stamp decides.
      JournalTranscriptEvidenceIndexer.rememberAll([
        _entry(id: 'legacy', provenance: TranscriptProvenance.unknownLegacy),
        _entry(id: 'spoken', provenance: TranscriptProvenance.speechToText),
      ]);

      expect(TranscriptEvidenceIndex.hasSource('legacy'), isFalse);
      expect(TranscriptEvidenceIndex.hasSource('spoken'), isTrue);
    });
  });

  group('what a legacy entry shows the user', () {
    Widget host(List<InsightEvidenceLine> lines) => MaterialApp(
      home: Scaffold(body: EvidenceCitationList(lines: lines)),
    );

    testWidgets('a claim about a legacy entry renders the legacy notice', (
      tester,
    ) async {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(id: 'legacy', provenance: TranscriptProvenance.unknownLegacy),
      );

      await tester.pumpWidget(
        host([
          InsightEvidenceLine(
            entryId: 'legacy',
            quote: _spoken,
            recordedAt: DateTime.utc(2026, 6, 1),
          ),
        ]),
      );

      // The invariant that matters is unchanged: the stored words are not put
      // on screen as the user's own. What changed is the explanation — an
      // unverifiable origin is not the same fact as an unsupported claim, and
      // this used to report the latter.
      expect(find.byKey(EvidenceCitationCard.cardKey), findsNothing);
      expect(find.textContaining(_spoken), findsNothing);
      expect(find.byKey(LegacyProvenanceNotice.noticeKey), findsOneWidget);
      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsNothing);
    });

    testWidgets('the same claim about a stamped entry renders the quote', (
      tester,
    ) async {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(id: 'spoken', provenance: TranscriptProvenance.speechToText),
      );

      await tester.pumpWidget(
        host([
          InsightEvidenceLine(
            entryId: 'spoken',
            quote: _spoken,
            recordedAt: DateTime.utc(2026, 6, 1),
          ),
        ]),
      );

      expect(find.byKey(EvidenceCitationCard.cardKey), findsOneWidget);
      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsNothing);
    });
  });

  group('write sites stamp what they know', () {
    test('capture text is stamped as speech-to-text and stays quotable', () {
      final stamped = applyFinalTranscriptToVoiceEntry(
        _entry(transcript: '', provenance: TranscriptProvenance.unknownLegacy),
        finalTranscript: _spoken,
        provenance: TranscriptProvenance.speechToText,
      );

      expect(stamped.transcript, _spoken);
      expect(stamped.transcriptProvenance, TranscriptProvenance.speechToText);

      JournalTranscriptEvidenceIndexer.rememberEntry(stamped);
      expect(TranscriptEvidenceIndex.transcriptFor(stamped.id), _spoken);
    });

    test('a user correction is stamped as user-edited and stays quotable', () {
      const corrected = 'I said yes to the extra project while already stretched.';
      final stamped = applyFinalTranscriptToVoiceEntry(
        _entry(provenance: TranscriptProvenance.unknownLegacy),
        finalTranscript: corrected,
        provenance: TranscriptProvenance.userEdited,
      );

      expect(stamped.transcript, corrected);
      expect(stamped.transcriptProvenance, TranscriptProvenance.userEdited);

      JournalTranscriptEvidenceIndexer.rememberEntry(stamped);
      expect(TranscriptEvidenceIndex.transcriptFor(stamped.id), corrected);
    });

    test('unusable new text cannot promote the text already stored', () {
      // `finalTranscript: null` falls back to what the entry already held.
      // That older text keeps its own provenance rather than inheriting the
      // caller's, so a failed transcription cannot make legacy text quotable.
      final unchanged = applyFinalTranscriptToVoiceEntry(
        _entry(provenance: TranscriptProvenance.unknownLegacy),
        finalTranscript: null,
        provenance: TranscriptProvenance.speechToText,
      );

      expect(unchanged.transcript, _spoken);
      expect(unchanged.transcriptProvenance, TranscriptProvenance.unknownLegacy);
    });
  });

  group('provenance travels with the transcript', () {
    test('a conflict merge keeps the winning side\'s stamp', () {
      final local = _entry(
        transcript: 'local words that were spoken aloud',
        provenance: TranscriptProvenance.speechToText,
        revision: 2,
        updatedAt: DateTime.utc(2026, 6, 3),
      );
      final remote = _entry(
        transcript: 'remote words of unknown origin',
        provenance: TranscriptProvenance.unknownLegacy,
        revision: 1,
        updatedAt: DateTime.utc(2026, 6, 2),
      );

      final merged = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(merged.entry.transcript, local.transcript);
      expect(merged.entry.transcriptProvenance, TranscriptProvenance.speechToText);
    });

    test('a merge that takes remote text takes remote provenance', () {
      final local = _entry(
        transcript: 'local words of unknown origin',
        provenance: TranscriptProvenance.unknownLegacy,
        revision: 1,
        updatedAt: DateTime.utc(2026, 6, 2),
      );
      final remote = _entry(
        transcript: 'remote words that were spoken aloud',
        provenance: TranscriptProvenance.speechToText,
        revision: 3,
        updatedAt: DateTime.utc(2026, 6, 4),
      );

      final merged = JournalConflictResolver.resolve(local: local, remote: remote);

      expect(merged.entry.transcript, remote.transcript);
      expect(merged.entry.transcriptProvenance, TranscriptProvenance.speechToText);
    });

    test('the encrypted sync snapshot round-trips every member', () {
      final entries = [
        _entry(id: 'a', provenance: TranscriptProvenance.speechToText),
        _entry(id: 'b', provenance: TranscriptProvenance.userEdited),
        _entry(id: 'c', provenance: TranscriptProvenance.unknownLegacy),
      ];

      final snapshot = buildEncryptedJournalSnapshot(
        deviceId: 'device-1',
        accountNamespace: 'ns',
        entries: entries,
        updatedAt: DateTime.utc(2026, 6, 5),
      );
      // Through the wire format the server stores as an opaque blob.
      final wire = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(snapshot)) as Map,
      );
      final restored = journalEntriesFromSnapshot(wire);

      expect(restored.map((e) => e.transcriptProvenance).toList(), [
        TranscriptProvenance.speechToText,
        TranscriptProvenance.userEdited,
        TranscriptProvenance.unknownLegacy,
      ]);
    });

    test('an older client that drops the field yields legacy, not trust', () {
      // Simulates a peer or server that re-serialises the entry without
      // understanding provenance. The value is lost, and what is read back is
      // the untrusted member rather than the one the sender actually held.
      final json = _entry(provenance: TranscriptProvenance.speechToText).toJson()
        ..remove('transcriptProvenance');

      expect(
        JournalEntry.fromJson(json).transcriptProvenance,
        TranscriptProvenance.unknownLegacy,
      );
    });

    test('local backup export and restore preserve the stamp', () {
      final exported = [
        for (final entry in [
          _entry(id: 'a', provenance: TranscriptProvenance.speechToText),
          _entry(id: 'b', provenance: TranscriptProvenance.userEdited),
          _entry(id: 'c', provenance: TranscriptProvenance.unknownLegacy),
        ])
          (entry.toJson()..remove('localAudioPath')),
      ];
      final payload = {
        'archive_backup_version': archiveBackupVersion,
        'exported_at': DateTime.utc(2026, 6, 6).toIso8601String(),
        'journal_entries': exported,
        'prefs': <String, dynamic>{},
      };

      final result = LocalBackupBuilder.validateJson(jsonEncode(payload));

      expect(result.backup, isNotNull);
      expect(
        result.backup!.entries.map((e) => e.transcriptProvenance).toList(),
        [
          TranscriptProvenance.speechToText,
          TranscriptProvenance.userEdited,
          TranscriptProvenance.unknownLegacy,
        ],
      );
    });
  });

  test('an entry restored from backup keeps its sync status untouched', () {
    // Guards the surrounding assumption of the round-trip tests above: the
    // provenance field is additive and does not disturb existing decoding.
    final decoded = JournalEntry.fromJson(
      _entry(provenance: TranscriptProvenance.userEdited).toJson(),
    );
    expect(decoded.syncStatus, SyncStatus.localOnly);
  });
}
