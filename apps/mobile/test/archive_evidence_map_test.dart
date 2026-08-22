import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/archive_evidence_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
  captureContextTag: captureContextTag,
);

JournalEntry _degradedVoiceEntry({
  String id = 'd1',
  String? captureContextTag,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
  durationSeconds: 20,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  captureContextTag: captureContextTag,
);

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
];

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  group('ArchiveEvidenceMapEngine', () {
    test('0 usable moments hides map card', () {
      final map = ArchiveEvidenceMapEngine.build(entries: const []);
      expect(map.showCard, isFalse);
    });

    test('degraded-only entries hide map card', () {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _degradedVoiceEntry(captureContextTag: CaptureContextTagIds.work),
        ],
      );
      expect(map.showCard, isFalse);
    });

    test('one tagged moment shows one tagged moment copy', () {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
        ],
      );
      expect(map.showCard, isTrue);
      expect(
        map.strongestContextLine,
        VisibleArchiveProofCopy.archiveEvidenceMapOneTagged,
      );
      expect(
        map.nextActionLine,
        VisibleArchiveProofCopy.archiveEvidenceMapAddAnother,
      );
    });

    test('same-context tags show strongest context copy', () {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
        ],
      );
      expect(
        map.strongestContextLine,
        VisibleArchiveProofCopy.archiveEvidenceMapMostEvidenceIn('Work'),
      );
      expect(
        map.nextActionLine,
        VisibleArchiveProofCopy.archiveEvidenceMapAddDifferentContext,
      );
    });

    test('mixed tags show multiple contexts', () {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      expect(
        map.strongestContextLine,
        VisibleArchiveProofCopy.archiveEvidenceMapSpansContexts,
      );
      expect(map.rows.length, 2);
    });

    test('untagged usable entries appear as Untagged row', () {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day moment two.',
            createdAt: DateTime(2026, 6, 11),
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'Another untagged moment before I could leave for the day moment three.',
            createdAt: DateTime(2026, 6, 12),
          ),
        ],
      );
      expect(map.rows.last.rowId, ArchiveEvidenceMapRowIds.untagged);
      expect(map.rows.last.label, 'Untagged');
      expect(map.rows.last.count, 2);
      expect(
        map.nextActionLine,
        VisibleArchiveProofCopy.archiveEvidenceMapUntaggedSuggest,
      );
    });

    test('degraded tagged entries do not count as usable evidence', () {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _degradedVoiceEntry(captureContextTag: CaptureContextTagIds.home),
        ],
      );
      expect(map.usableCount, 1);
      expect(map.rows.length, 1);
      expect(map.excludedNote, isNotNull);
    });

    test('top contexts sort by count with stable alphabetical tie-break', () {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day moment two.',
            createdAt: DateTime(2026, 6, 10),
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'Another work moment before I could leave for the day moment three.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e4',
            transcript:
                'Home felt loud before I could settle into the evening moment one.',
            createdAt: DateTime(2026, 6, 12),
            captureContextTag: CaptureContextTagIds.home,
          ),
          _voiceEntry(
            id: 'e5',
            transcript:
                'Home felt loud again before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 13),
            captureContextTag: CaptureContextTagIds.home,
          ),
          _voiceEntry(
            id: 'e6',
            transcript:
                'Family plans shifted again before I could catch my breath.',
            createdAt: DateTime(2026, 6, 14),
            captureContextTag: CaptureContextTagIds.family,
          ),
        ],
      );
      expect(map.rows.first.label, 'Work');
      expect(map.rows.first.count, 3);
      expect(map.rows[1].label, 'Home');
      expect(map.rows[1].count, 2);
      expect(map.rows[2].label, 'Family');
      expect(map.rows[2].count, 1);
      expect(map.thinContextsLine, contains('Family'));
    });

    test('share-safe proof does not include context tags or map data', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      final shareText = proof.lines.join('\n').toLowerCase();
      expect(shareText, isNot(contains('evidence map')));
      expect(shareText, isNot(contains('untagged')));
      expect(shareText, isNot(contains('work:')));
    });

    test('copy avoids banned language', () {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      _expectNoBannedCopy([
        map.title,
        map.subtitle,
        if (map.strongestContextLine != null) map.strongestContextLine!,
        if (map.thinContextsLine != null) map.thinContextsLine!,
        if (map.untaggedLine != null) map.untaggedLine!,
        if (map.nextActionLine != null) map.nextActionLine!,
        if (map.excludedNote != null) map.excludedNote!,
        ...map.rows.map((row) => '${row.label}: ${row.count}'),
        VisibleArchiveProofCopy.archiveEvidenceMapMostEvidenceIn('Work'),
        VisibleArchiveProofCopy.archiveEvidenceMapThinContexts(['Home']),
      ]);
    });
  });

  group('ArchiveEvidenceMapCard', () {
    testWidgets('hidden map renders nothing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveEvidenceMapCard(map: ArchiveEvidenceMap.hidden()),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('archive_evidence_map_card')), findsNothing);
    });

    testWidgets('rows and bars render for mixed contexts', (tester) async {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'Home felt loud before I could settle into the evening moment three.',
            createdAt: DateTime(2026, 6, 12),
            captureContextTag: CaptureContextTagIds.home,
          ),
          _voiceEntry(
            id: 'e4',
            transcript:
                'Another untagged moment before I could leave for the day moment four.',
            createdAt: DateTime(2026, 6, 13),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SingleChildScrollView(child: ArchiveEvidenceMapCard(map: map)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_evidence_map_card')),
        findsOneWidget,
      );
      expect(find.text('Evidence map'), findsOneWidget);
      expect(
        find.byKey(const Key('archive_evidence_map_row_work')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_evidence_map_row_untagged')),
        findsOneWidget,
      );
      expect(find.textContaining('Work: 2 moments'), findsOneWidget);
      expect(find.textContaining('Untagged: 1 moment'), findsOneWidget);
    });

    testWidgets('row tap invokes onRowTap with context id', (tester) async {
      final map = ArchiveEvidenceMapEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      String? tappedId;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SingleChildScrollView(
            child: ArchiveEvidenceMapCard(
              map: map,
              onRowTap: (tagId) => tappedId = tagId,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_evidence_map_row_tap_work')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('archive_evidence_map_row_tap_work')),
      );
      await tester.pump();
      expect(tappedId, CaptureContextTagIds.work);
    });
  });
}