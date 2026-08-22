import 'package:archiveme_mobile/features/belief_evidence/evidence/journal_transcript_evidence_indexer.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/legacy_transcript_registry.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/belief_evidence/evidence/verbatim_evidence.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_notice.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _quotableEntry = 'entry_quotable';
const _legacyEntry = 'entry_legacy';
final _recordedAt = DateTime(2026, 8, 14);

const _transcript =
    'I keep telling myself I want to speak at the conference, but every time '
    'the invite lands I find a reason to say no.';

Widget _host(Widget child, {double textScale = 1, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
}

JournalEntry _entry({
  required String id,
  required TranscriptProvenance provenance,
  String? audioPath,
}) {
  return JournalEntry(
    id: id,
    transcript: _transcript,
    createdAt: _recordedAt,
    durationSeconds: 42,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
    transcriptProvenance: provenance,
    localAudioPath: audioPath,
  );
}

InsightEvidenceLine _line(String entryId, String quote) =>
    InsightEvidenceLine(entryId: entryId, quote: quote, recordedAt: _recordedAt);

void main() {
  setUp(() {
    TranscriptEvidenceIndex.resetForTest();
    LegacyTranscriptRegistry.resetForTest();
  });
  tearDown(() {
    TranscriptEvidenceIndex.resetForTest();
    LegacyTranscriptRegistry.resetForTest();
  });

  group('indexing separates quotable from legacy', () {
    test('a quotable entry becomes an evidence source and nothing else', () {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _quotableEntry,
          provenance: TranscriptProvenance.speechToText,
        ),
      );

      expect(TranscriptEvidenceIndex.hasSource(_quotableEntry), isTrue);
      expect(LegacyTranscriptRegistry.isLegacy(_quotableEntry), isFalse);
    });

    test('a legacy entry contributes no quotable text but is recorded', () {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _legacyEntry,
          provenance: TranscriptProvenance.unknownLegacy,
          audioPath: '/tmp/does-not-exist.m4a',
        ),
      );

      // The text stays out of reach of the verifier: this is the property that
      // stops generated wording being shown back as the user's own.
      expect(TranscriptEvidenceIndex.hasSource(_legacyEntry), isFalse);
      expect(TranscriptEvidenceIndex.transcriptFor(_legacyEntry), isNull);
      // But the reason is now knowable, which is what the notice needs.
      expect(LegacyTranscriptRegistry.isLegacy(_legacyEntry), isTrue);
      expect(
        LegacyTranscriptRegistry.recordFor(_legacyEntry)?.audioPath,
        '/tmp/does-not-exist.m4a',
      );
    });

    test('a user-edited transcript stays quotable', () {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(id: 'edited', provenance: TranscriptProvenance.userEdited),
      );

      expect(TranscriptEvidenceIndex.hasSource('edited'), isTrue);
      expect(LegacyTranscriptRegistry.isLegacy('edited'), isFalse);
    });
  });

  group('EvidenceCitationList.stateFor', () {
    test('quotable text resolves to the quoted state', () {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _quotableEntry,
          provenance: TranscriptProvenance.speechToText,
        ),
      );

      expect(
        EvidenceCitationList.stateFor([
          _line(_quotableEntry, 'I find a reason to say no'),
        ]),
        EvidenceCitationState.quoted,
      );
    });

    test('a legacy entry resolves to the unverified state', () {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _legacyEntry,
          provenance: TranscriptProvenance.unknownLegacy,
        ),
      );

      expect(
        EvidenceCitationList.stateFor([
          _line(_legacyEntry, 'I find a reason to say no'),
        ]),
        EvidenceCitationState.provenanceUnverified,
      );
    });

    test('an entry nobody indexed is still unsupported, not legacy', () {
      expect(
        EvidenceCitationList.stateFor([
          _line('never_seen', 'I find a reason to say no'),
        ]),
        EvidenceCitationState.unsupported,
      );
    });

    test('a checkable line that fails outranks a legacy line', () {
      // One entry's stored text was read and does not contain the words. That
      // is a stronger statement than "origin unknown", and the honest thing to
      // report about the claim as a whole.
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _quotableEntry,
          provenance: TranscriptProvenance.speechToText,
        ),
      );
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _legacyEntry,
          provenance: TranscriptProvenance.unknownLegacy,
        ),
      );

      expect(
        EvidenceCitationList.stateFor([
          _line(_quotableEntry, 'You avoid visibility because of fear'),
          _line(_legacyEntry, 'I find a reason to say no'),
        ]),
        EvidenceCitationState.unsupported,
      );
    });

    test('legacy entry ids are listed once, in order', () {
      for (final id in ['a', 'b']) {
        JournalTranscriptEvidenceIndexer.rememberEntry(
          _entry(id: id, provenance: TranscriptProvenance.unknownLegacy),
        );
      }

      expect(
        EvidenceCitationList.legacyEntryIds([
          _line('a', 'one quote here'),
          _line('b', 'another quote here'),
          _line('a', 'a third quote here'),
        ]),
        ['a', 'b'],
      );
    });
  });

  group('the three states render differently', () {
    testWidgets('quotable renders a citation card and neither notice', (
      tester,
    ) async {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _quotableEntry,
          provenance: TranscriptProvenance.speechToText,
        ),
      );

      await tester.pumpWidget(
        _host(
          EvidenceCitationList(
            lines: [_line(_quotableEntry, 'I find a reason to say no')],
          ),
        ),
      );

      expect(find.byKey(EvidenceCitationCard.cardKey), findsOneWidget);
      expect(find.byKey(LegacyProvenanceNotice.noticeKey), findsNothing);
      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsNothing);
    });

    testWidgets('legacy renders the legacy notice and not the generic one', (
      tester,
    ) async {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _legacyEntry,
          provenance: TranscriptProvenance.unknownLegacy,
        ),
      );

      await tester.pumpWidget(
        _host(
          EvidenceCitationList(
            lines: [_line(_legacyEntry, 'I find a reason to say no')],
          ),
        ),
      );

      expect(find.byKey(LegacyProvenanceNotice.noticeKey), findsOneWidget);
      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsNothing);
      expect(find.byKey(EvidenceCitationCard.cardKey), findsNothing);
      expect(find.text(LegacyProvenanceCopy.title), findsOneWidget);
      expect(find.text(LegacyProvenanceCopy.body), findsOneWidget);
      // The old fall-through, which read as a transient load failure.
      expect(
        find.text(EvidenceCitationCopy.sourceUnavailableTitle),
        findsNothing,
      );
    });

    testWidgets('a genuinely unbacked claim still gets the generic notice', (
      tester,
    ) async {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _quotableEntry,
          provenance: TranscriptProvenance.speechToText,
        ),
      );

      await tester.pumpWidget(
        _host(
          EvidenceCitationList(
            lines: [
              _line(_quotableEntry, 'You avoid visibility because of fear'),
            ],
          ),
        ),
      );

      expect(find.byKey(UngroundedEvidenceNotice.noticeKey), findsOneWidget);
      expect(find.byKey(LegacyProvenanceNotice.noticeKey), findsNothing);
      expect(find.text(EvidenceCitationCopy.ungroundedTitle), findsOneWidget);
      expect(find.text(LegacyProvenanceCopy.title), findsNothing);
    });

    testWidgets('the two notices do not share a look', (tester) async {
      JournalTranscriptEvidenceIndexer.rememberEntry(
        _entry(
          id: _legacyEntry,
          provenance: TranscriptProvenance.unknownLegacy,
        ),
      );

      await tester.pumpWidget(
        _host(
          Column(
            children: [
              EvidenceCitationList(
                lines: [_line(_legacyEntry, 'I find a reason to say no')],
              ),
              const UngroundedEvidenceNotice(
                failure: EvidenceGroundingFailure.notPresentInSource,
              ),
            ],
          ),
        ),
      );

      BoxDecoration decorationOf(Key key) => tester
              .widget<Container>(find.byKey(key))
              .decoration!
          as BoxDecoration;

      final legacy = decorationOf(LegacyProvenanceNotice.noticeKey);
      final ungrounded = decorationOf(UngroundedEvidenceNotice.noticeKey);
      expect(legacy.color, isNot(ungrounded.color));

      // The legacy state must not borrow the warning colour: it is the resting
      // state of every pre-existing entry, so it cannot look like a fault.
      final legacyIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(LegacyProvenanceNotice.noticeKey),
          matching: find.byType(Icon),
        ),
      );
      final ungroundedIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(UngroundedEvidenceNotice.noticeKey),
          matching: find.byType(Icon),
        ),
      );
      expect(legacyIcon.icon, isNot(ungroundedIcon.icon));
      expect(legacyIcon.color, isNot(ungroundedIcon.color));
    });
  });

  group('presentation', () {
    testWidgets('announces the whole explanation as one node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const LegacyProvenanceNotice()));

      final label = LegacyProvenanceCopy.semantics(recovery: '');
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(label, contains(LegacyProvenanceCopy.title));
      expect(label, contains(LegacyProvenanceCopy.helper));
      handle.dispose();
    });

    testWidgets('lays out at phone, tablet, and 2x text without overflow', (
      tester,
    ) async {
      for (final size in const [Size(390, 844), Size(1024, 1366)]) {
        for (final scale in const [1.0, 2.0, 3.0]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _host(const LegacyProvenanceNotice(), textScale: scale),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'overflowed at $size @${scale}x',
          );
        }
      }
    });

    testWidgets('renders in the dark theme', (tester) async {
      await tester.pumpWidget(
        _host(const LegacyProvenanceNotice(), theme: AppTheme.dark()),
      );

      expect(find.byKey(LegacyProvenanceNotice.noticeKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the recover slot only when one is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const LegacyProvenanceNotice()));
      expect(find.byKey(const Key('recovery_slot')), findsNothing);

      await tester.pumpWidget(
        _host(
          const LegacyProvenanceNotice(
            recovery: SizedBox(key: Key('recovery_slot')),
          ),
        ),
      );
      expect(find.byKey(const Key('recovery_slot')), findsOneWidget);
    });
  });
}
