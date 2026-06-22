import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/belief_evidence_screen.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/screens/weekly_archive_review_screen.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/activation/belief_evidence_trail.dart';
import 'package:voicememory_mobile/features/activation/weekly_archive_review.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/shareable_archive_proof_card.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: 'pressure moment',
  );
}

List<PressureCheckInRecord> _sensitiveThread3() => [
      _record(
        id: 'a',
        daysAgo: 7,
        contextIds: const ['work'],
        fear: 'Maria said the divorce paperwork is late again',
      ),
      _record(
        id: 'b',
        daysAgo: 3,
        contextIds: const ['work'],
        fear: 'Argued with Maria about money at the hospital',
      ),
      _record(
        id: 'c',
        daysAgo: 0,
        contextIds: const ['work'],
        fear: 'I kept checking the divorce emails after midnight',
      ),
    ];

List<PressureCheckInRecord> _unrelatedRecords() => [
      _record(id: 'u0', daysAgo: 2, optionId: 'could_not_stop'),
      _record(id: 'u1', daysAgo: 1, optionId: 'guilty_resting'),
      _record(id: 'u2', daysAgo: 0, optionId: 'had_to_prove_enough'),
    ];

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
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
    );

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
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
    );

List<JournalEntry> _journalEntries(int count) => List.generate(
      count,
      (i) => _voiceEntry(
        id: 'e$i',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired number $i.',
        createdAt: DateTime(2026, 6, 9 + i, 12),
      ),
    );

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'share to unlock',
  'pattern found',
  'voicememory',
  'you always',
  'prove yourself',
  'my trauma',
  'my anxiety',
];

void _expectNoBannedCopy(String text) {
  final lower = text.toLowerCase();
  for (final word in _bannedWords) {
    expect(
      lower,
      isNot(contains(word)),
      reason: 'share text must not contain "$word"',
    );
  }
}

void _expectPrivacySafe(String text, {Iterable<String> forbidden = const []}) {
  expect(text, contains('No private entries shared.'));
  expect(
    text,
    contains('ArchiveMe — your private evidence-based life archive.'),
  );
  for (final term in forbidden) {
    expect(
      text.toLowerCase(),
      isNot(contains(term.toLowerCase())),
      reason: 'must not leak "$term"',
    );
  }
  _expectNoBannedCopy(text);
}

void main() {
  const engine = ShareableArchiveProofEngine();

  group('Shareable archive proof engine — eligibility', () {
    test('no share card before three usable journal entries', () {
      for (final count in [0, 1, 2]) {
        expect(
          engine.buildFromJournal(entries: _journalEntries(count)).hasProof,
          isFalse,
        );
      }
    });

    test('three usable journal entries show variant B', () {
      final proof = engine.buildFromJournal(entries: _journalEntries(3));
      expect(proof.hasProof, isTrue);
      expect(proof.title, 'Share-safe proof');
      expect(proof.lines, [ShareableArchiveProof.variantB]);
    });

    test('four usable journal entries show variant A', () {
      final proof = engine.buildFromJournal(entries: _journalEntries(4));
      expect(proof.lines, [ShareableArchiveProof.variantA]);
    });

    test('five usable journal entries show variant C', () {
      final proof = engine.buildFromJournal(entries: _journalEntries(5));
      expect(proof.lines, [ShareableArchiveProof.variantC]);
    });

    test('pressure connected thread uses cautious variant without user text', () {
      final proof = engine.build(_sensitiveThread3(), now: _base);
      expect(proof.hasProof, isTrue);
      expect(proof.lines, [ShareableArchiveProof.variantC]);
    });

    test('no share card for unrelated pressure records without three entries', () {
      expect(
        engine.build(_unrelatedRecords(), savedToday: true, entryCount: 1, now: _base)
            .hasProof,
        isFalse,
      );
      expect(engine.build(_unrelatedRecords(), now: _base).hasProof, isFalse);
    });

    test('degraded journal entries do not count toward three usable entries', () {
      final entries = [
        ..._journalEntries(2),
        _degradedVoiceEntry(id: 'e3'),
      ];
      expect(engine.buildFromJournal(entries: entries).hasProof, isFalse);
    });
  });

  group('Shareable archive proof — privacy safeguards', () {
    test('share text contains required privacy footer and product line', () {
      final proof = engine.buildFromJournal(entries: _journalEntries(5));
      _expectPrivacySafe(proof.shareText);
    });

    test('journal share text never includes raw transcript or snippets', () {
      const sensitive =
          'Maria told me about the divorce paperwork at the hospital again';
      final entries = List.generate(
        5,
        (i) => _voiceEntry(
          id: 'e$i',
          transcript: sensitive,
          createdAt: DateTime(2026, 6, 9 + i, 12),
        ),
      );
      final proof = engine.buildFromJournal(entries: entries);
      _expectPrivacySafe(
        proof.shareText,
        forbidden: const [
          'maria',
          'divorce',
          'hospital',
          'paperwork',
          sensitive,
        ],
      );
    });

    test('pressure share text never includes private terms from records', () {
      final proof = engine.build(_sensitiveThread3(), now: _base);
      _expectPrivacySafe(
        proof.shareText,
        forbidden: const [
          'maria',
          'divorce',
          'hospital',
          'money',
          'paperwork',
          'midnight',
          'emails',
        ],
      );
    });

    test('share copy includes ArchiveMe and never VoiceMemory', () {
      for (final proof in [
        engine.buildFromJournal(entries: _journalEntries(3)),
        engine.build(_sensitiveThread3(), now: _base),
      ]) {
        expect(proof.shareText, contains('ArchiveMe'));
        expect(proof.shareText, isNot(contains('VoiceMemory')));
      }
    });
  });

  group('Shareable archive proof card', () {
    testWidgets('renders preview with privacy footer and copy/share actions', (
      tester,
    ) async {
      final proof = engine.buildFromJournal(entries: _journalEntries(5));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareableArchiveProofCard(
                proof: proof,
                onShare: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('shareable_archive_proof_card')), findsOneWidget);
      expect(find.text('Share-safe proof'), findsOneWidget);
      expect(find.text(ShareableArchiveProof.variantC), findsOneWidget);
      expect(find.text('No private entries shared.'), findsOneWidget);
      expect(
        find.text('ArchiveMe — your private evidence-based life archive.'),
        findsOneWidget,
      );
      expect(find.byWidgetPredicate((w) => w is ButtonStyleButton), findsNWidgets(2));
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('copy puts exact share text on clipboard', (tester) async {
      final proof = engine.buildFromJournal(entries: _journalEntries(4));
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareableArchiveProofCard(
              proof: proof,
              onShare: (_) async {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('shareable_proof_copy')));
      await tester.pump();

      final copyCall = calls.firstWhere((c) => c.method == 'Clipboard.setData');
      expect((copyCall.arguments as Map)['text'], proof.shareText);
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('share hands exact share text to share action', (tester) async {
      final proof = engine.buildFromJournal(entries: _journalEntries(3));
      String? shared;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareableArchiveProofCard(
              proof: proof,
              onShare: (text) async => shared = text,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('shareable_proof_share')));
      await tester.pump();

      expect(shared, proof.shareText);
    });

    testWidgets('renders nothing without proof', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareableArchiveProofCard(
              proof: ShareableArchiveProof.none(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('shareable_archive_proof_card')), findsNothing);
    });
  });

  group('Activation screen integration', () {
    testWidgets('weekly review screen shows optional share proof at five entries', (
      tester,
    ) async {
      final review = WeeklyArchiveReviewEngine.build(entries: _journalEntries(5));
      final shareProof = engine.buildFromJournal(entries: _journalEntries(5));

      await tester.binding.setSurfaceSize(const Size(390, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: WeeklyArchiveReviewScreen(
            previewReview: review,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('weekly_archive_review_card')), findsOneWidget);
      expect(find.byKey(const Key('shareable_archive_proof_card')), findsNothing);
    });

    testWidgets('belief evidence preview does not crash without share load', (
      tester,
    ) async {
      final trail = BeliefEvidenceTrailEngine.build(entries: _journalEntries(4));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BeliefEvidenceScreen(previewTrail: trail),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('belief_evidence_trail_card')), findsOneWidget);
      expect(find.byKey(const Key('shareable_archive_proof_card')), findsNothing);
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('share card renders near proof counter with connected evidence', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: _sensitiveThread3(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shareCard = find.byKey(const Key('shareable_archive_proof_card'));
      final proofCard = find.byKey(const Key('archive_proof_counter_card'));
      expect(shareCard, findsOneWidget);
      expect(proofCard, findsOneWidget);
      expect(
        tester.getTopLeft(proofCard).dy,
        lessThan(tester.getTopLeft(shareCard).dy),
      );
      _expectPrivacySafe(
        engine.build(_sensitiveThread3(), now: _base).shareText,
      );
    });

    testWidgets('no share card without connected evidence', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: _unrelatedRecords(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shareable_archive_proof_card')), findsNothing);
    });
  });
}
