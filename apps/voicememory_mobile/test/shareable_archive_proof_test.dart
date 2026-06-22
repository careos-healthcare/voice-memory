import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_model.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
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

/// A connected work thread whose notes hold names and sensitive private
/// language — none of which may ever reach the share text.
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

/// Entries with no overlap at all — nothing connected yet.
List<PressureCheckInRecord> _unrelatedRecords() => [
  _record(id: 'u0', daysAgo: 2, optionId: 'could_not_stop'),
  _record(id: 'u1', daysAgo: 1, optionId: 'guilty_resting'),
  _record(id: 'u2', daysAgo: 0, optionId: 'had_to_prove_enough'),
];

void main() {
  const engine = ShareableArchiveProofEngine();

  group('Shareable archive proof engine — eligibility', () {
    test('no share card before enough evidence or a save', () {
      expect(engine.build(const [], now: _base).hasProof, isFalse);
      expect(
        engine.build([
          _record(id: 'a', contextIds: const ['work']),
        ], now: _base).hasProof,
        isFalse,
      );
      // Unconnected entries without a fresh save: nothing to share yet.
      expect(engine.build(_unrelatedRecords(), now: _base).hasProof, isFalse);
    });

    test('connected variant appears with a real thread', () {
      final proof = engine.build(_sensitiveThread3(), now: _base);
      expect(proof.hasProof, isTrue);
      expect(proof.title, 'My archive this week');
      expect(proof.lines, const [
        'My archive connected 3 recordings.',
        'One thread returned.',
        'I know what to check tomorrow.',
      ]);
    });

    test('starter variant appears right after a save without a thread', () {
      final proof = engine.build(
        _unrelatedRecords(),
        savedToday: true,
        entryCount: 1,
        now: _base,
      );
      expect(proof.hasProof, isTrue);
      expect(proof.lines, const [
        'I recorded one moment for my archive.',
        'Done for today.',
      ]);
    });
  });

  group('Shareable archive proof — privacy safeguards', () {
    test('default share copy never includes snippets or private terms', () {
      final proof = engine.build(_sensitiveThread3(), now: _base);
      final text = proof.shareText.toLowerCase();
      // Names, raw notes, and sensitive words from the user's entries.
      for (final private in const [
        'maria',
        'divorce',
        'hospital',
        'money',
        'paperwork',
        'midnight',
        'emails',
        'work', // even the thread term stays private
      ]) {
        expect(
          text,
          isNot(contains(private)),
          reason: 'share text must not contain "$private"',
        );
      }
    });

    test('share copy is counts and fixed lines only', () {
      final proof = engine.build(_sensitiveThread3(), now: _base);
      expect(
        proof.shareText,
        'My archive this week\n'
        'My archive connected 3 recordings.\n'
        'One thread returned.\n'
        'I know what to check tomorrow.\n'
        'Recorded with ArchiveMe.',
      );
    });

    test('copy includes ArchiveMe and never VoiceMemory', () {
      for (final proof in [
        engine.build(_sensitiveThread3(), now: _base),
        engine.build(_unrelatedRecords(), savedToday: true, entryCount: 1, now: _base),
      ]) {
        expect(proof.shareText, contains('ArchiveMe'));
        expect(proof.shareText, isNot(contains('VoiceMemory')));
      }
    });

    test('no streak, therapy, diagnosis, or health-claim words', () {
      for (final proof in [
        engine.build(_sensitiveThread3(), now: _base),
        engine.build(_unrelatedRecords(), savedToday: true, entryCount: 1, now: _base),
      ]) {
        final text = proof.shareText.toLowerCase();
        for (final banned in const [
          'streak',
          'therapy',
          'therapist',
          'diagnos',
          'treatment',
          'anxiety',
          'trauma',
          'cure',
          'heal',
          'disorder',
          'must',
          'should',
          'problem',
          'fix',
        ]) {
          expect(
            text,
            isNot(contains(banned)),
            reason: 'share text must not contain "$banned"',
          );
        }
      }
    });
  });

  group('Shareable archive proof card', () {
    testWidgets('renders the preview with copy and share actions only', (
      tester,
    ) async {
      final proof = engine.build(_sensitiveThread3(), now: _base);
      await tester.pumpWidget(
        MaterialApp(
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

      expect(
        find.byKey(const Key('shareable_archive_proof_card')),
        findsOneWidget,
      );
      expect(find.text('My archive this week'), findsOneWidget);
      expect(find.text('My archive connected 3 recordings.'), findsOneWidget);
      expect(find.text('Recorded with ArchiveMe.'), findsOneWidget);
      // Exactly two passive actions — no feed, no input, no extra surface.
      expect(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        findsNWidgets(2),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('copy puts the exact share text on the clipboard', (
      tester,
    ) async {
      final proof = engine.build(_sensitiveThread3(), now: _base);
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
      // Button confirms without leaving the screen or blocking anything.
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('share hands the exact share text to the share action', (
      tester,
    ) async {
      final proof = engine.build(_sensitiveThread3(), now: _base);
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
      expect(
        find.byKey(const Key('shareable_archive_proof_card')),
        findsNothing,
      );
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('share card renders near the proof counter with evidence', (
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
      // Existing cards stay; the share card sits right below the counter.
      expect(proofCard, findsOneWidget);
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(proofCard).dy,
        lessThan(tester.getTopLeft(shareCard).dy),
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

      expect(
        find.byKey(const Key('shareable_archive_proof_card')),
        findsNothing,
      );
    });
  });
}
