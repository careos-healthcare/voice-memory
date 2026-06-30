import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_gates.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_analytics.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_gates.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/repeat_return_check_card.dart';
import 'package:voicememory_mobile/widgets/record/repeat_return_check_change_proof_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 24,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'I said yes again',
      concreteObservation: 'Saying yes showed up again.',
      repeatedSignal: 'saying yes before ready',
    ),
  );
}

List<JournalEntry> _threeRelatedRepeatEntries() => [
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

List<JournalEntry> _fourEntriesWithRelatedReturn() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

List<JournalEntry> _fourEntriesWithUnrelatedReturn() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'Weather was nice on my walk through the park and felt calmer outside.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
  int entryCountAtCapture = 4,
}) {
  return RepeatReturnCheckRecord(
    entryId: entryId,
    choice: choice,
    entryCountAtCapture: entryCountAtCapture,
    createdAt: DateTime(2026, 6, 13),
  );
}

RepeatReturnCheckChangeProof _proofForChoice(RepeatReturnCheckChoice choice) {
  return RepeatReturnCheckChangeProof(
    title: RepeatReturnCheckCopy.changeProofTitle,
    body: RepeatReturnCheckTrendEngine.bodyForChoice(choice),
    latestChoice: choice,
  );
}

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/repeat_return_check/unused.json'));

  final Map<String, Map<String, dynamic>> jsonMaps = {};

  @override
  Future<Map<String, dynamic>?> readJsonMap(String key) async => jsonMaps[key];

  @override
  Future<void> writeJsonMap(String key, Map<String, dynamic> value) async {
    jsonMaps[key] = value;
  }
}

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  setUp(() async {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_repeat_return.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await RepeatReturnCheckStore.resetForTest();
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('RepeatReturnCheckGates', () {
    test('does not offer during first-three activation', () {
      expect(
        RepeatReturnCheckGates.hasRelatedRepeatSave(_threeRelatedRepeatEntries()),
        isFalse,
      );
      expect(
        FirstThreeSessionGates.minEntriesForUsefulArchive,
        3,
      );
    });

    test('offers after confirmed repeat when fourth entry is related', () {
      expect(
        RepeatReturnCheckGates.hasRelatedRepeatSave(
          _fourEntriesWithRelatedReturn(),
        ),
        isTrue,
      );
    });

    test('does not offer for unrelated fourth entry', () {
      expect(
        RepeatReturnCheckGates.hasRelatedRepeatSave(
          _fourEntriesWithUnrelatedReturn(),
        ),
        isFalse,
      );
    });

    test('does not re-offer after entry is completed', () {
      final entries = _fourEntriesWithRelatedReturn();
      final existing = RepeatReturnCheckRecord(
        entryId: 'e4',
        choice: RepeatReturnCheckChoice.same,
        entryCountAtCapture: 4,
        createdAt: DateTime(2026, 6, 13),
      );
      expect(
        RepeatReturnCheckGates.shouldOfferForEntry(
          entriesAfterSave: entries,
          existing: existing,
        ),
        isFalse,
      );
    });
  });

  group('RepeatReturnCheckEngine', () {
    test('returns offer for related fourth save', () {
      final offer = RepeatReturnCheckEngine.pendingForSave(
        entriesAfterSave: _fourEntriesWithRelatedReturn(),
      );
      expect(offer, isNotNull);
      expect(offer!.entryId, 'e4');
      expect(offer.entryCount, 4);
    });

    test('returns null during activation window', () {
      expect(
        RepeatReturnCheckEngine.pendingForSave(
          entriesAfterSave: _threeRelatedRepeatEntries(),
        ),
        isNull,
      );
    });
  });

  group('RepeatReturnCheckStore', () {
    test('persists metadata only — no transcript fields', () async {
      final prefs = _MemoryPrefs();
      final store = RepeatReturnCheckStore(prefs);

      await store.saveChoice(
        entryId: 'e4',
        choice: RepeatReturnCheckChoice.softer,
        entryCountAtCapture: 4,
      );

      final loaded = await store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.entryId, 'e4');
      expect(loaded.single.choice, RepeatReturnCheckChoice.softer);
      expect(loaded.single.entryCountAtCapture, 4);

      final raw = prefs.jsonMaps['repeatReturnCheckRecords_v1']!;
      final encoded = raw.toString();
      expect(encoded.contains('transcript'), isFalse);
      expect(encoded.contains('said yes'), isFalse);
    });

    test('dismiss marks entry completed without a choice', () async {
      final prefs = _MemoryPrefs();
      final store = RepeatReturnCheckStore(prefs);

      await store.dismiss(entryId: 'e4', entryCountAtCapture: 4);
      final loaded = await store.loadAll();
      expect(loaded.single.dismissed, isTrue);
      expect(loaded.single.choice, isNull);
      expect(loaded.single.completed, isTrue);
    });
  });

  group('RepeatReturnCheckGates change proof', () {
    test('does not show before any answered check', () {
      expect(
        RepeatReturnCheckGates.shouldShowChangeProofCard(
          entryCount: 4,
          viewingConfirmedRepeat: true,
          isRecording: false,
          isPostSave: false,
          records: const [],
        ),
        isFalse,
      );
    });

    test('does not show during first-three activation', () {
      expect(
        RepeatReturnCheckGates.shouldShowChangeProofCard(
          entryCount: 3,
          viewingConfirmedRepeat: true,
          isRecording: false,
          isPostSave: false,
          records: [_answeredRecord(entryId: 'e3', choice: RepeatReturnCheckChoice.stronger)],
        ),
        isFalse,
      );
    });

    test('does not show while recording', () {
      expect(
        RepeatReturnCheckGates.shouldShowChangeProofCard(
          entryCount: 4,
          viewingConfirmedRepeat: true,
          isRecording: true,
          isPostSave: false,
          records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same)],
        ),
        isFalse,
      );
    });

    test('does not show on post-save surface', () {
      expect(
        RepeatReturnCheckGates.shouldShowChangeProofCard(
          entryCount: 4,
          viewingConfirmedRepeat: true,
          isRecording: false,
          isPostSave: true,
          records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same)],
        ),
        isFalse,
      );
    });

    test('shows when answered check exists on confirmed repeat ready surface', () {
      expect(
        RepeatReturnCheckGates.shouldShowChangeProofCard(
          entryCount: 4,
          viewingConfirmedRepeat: true,
          isRecording: false,
          isPostSave: false,
          records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer)],
        ),
        isTrue,
      );
    });
  });

  group('RepeatReturnCheckEngine change proof', () {
    test('returns null before any answered check', () {
      expect(
        RepeatReturnCheckEngine.changeProofForReady(
          entryCount: 4,
          viewingConfirmedRepeat: true,
          isRecording: false,
          isPostSave: false,
          records: const [],
        ),
        isNull,
      );
    });

    test('stronger response shows getting louder copy', () {
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.stronger)],
      );
      expect(proof, isNotNull);
      expect(proof!.body, RepeatReturnCheckCopy.trendGettingLouder);
      expect(proof.title, RepeatReturnCheckCopy.changeProofTitle);
      expect(proof.supportLine, isNull);
    });

    test('softer response shows softer than before copy', () {
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer)],
      );
      expect(proof!.body, RepeatReturnCheckCopy.trendSofterThanBefore);
    });

    test('same response shows steady copy', () {
      final proof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same)],
      );
      expect(proof!.body, RepeatReturnCheckCopy.trendSteady);
    });

    test('returns null during first-three activation even with answers', () {
      expect(
        RepeatReturnCheckEngine.changeProofForReady(
          entryCount: 3,
          viewingConfirmedRepeat: true,
          isRecording: false,
          isPostSave: false,
          records: [_answeredRecord(entryId: 'e3', choice: RepeatReturnCheckChoice.stronger)],
        ),
        isNull,
      );
    });

    test('returns null while recording', () {
      expect(
        RepeatReturnCheckEngine.changeProofForReady(
          entryCount: 4,
          viewingConfirmedRepeat: true,
          isRecording: true,
          isPostSave: false,
          records: [_answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same)],
        ),
        isNull,
      );
    });
  });

  group('RepeatReturnCheckTrendEngine change proof body', () {
    test('maps single stronger answer to louder copy', () {
      expect(
        RepeatReturnCheckTrendEngine.changeProofBody([
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.stronger),
        ]),
        RepeatReturnCheckCopy.trendGettingLouder,
      );
    });

    test('maps single softer answer to softer copy', () {
      expect(
        RepeatReturnCheckTrendEngine.changeProofBody([
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ]),
        RepeatReturnCheckCopy.trendSofterThanBefore,
      );
    });

    test('maps single same answer to steady copy', () {
      expect(
        RepeatReturnCheckTrendEngine.changeProofBody([
          _answeredRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same),
        ]),
        RepeatReturnCheckCopy.trendSteady,
      );
    });
  });

  group('RepeatReturnCheckChangeProofCard', () {
    testWidgets('renders change proof copy and record-next link', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepeatReturnCheckChangeProofCard(
              proof: _proofForChoice(RepeatReturnCheckChoice.stronger),
              entryCount: 4,
              surface: 'record',
              onRecordNext: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('repeat_return_check_change_proof_card')), findsOneWidget);
      expect(find.text(RepeatReturnCheckCopy.changeProofTitle), findsOneWidget);
      expect(find.text(RepeatReturnCheckCopy.trendGettingLouder), findsOneWidget);
      expect(find.text(RepeatReturnCheckCopy.changeProofSupportLine), findsNothing);
      expect(find.text(RepeatReturnCheckCopy.changeProofRecordNextCta), findsOneWidget);
    });

    testWidgets('shows softer body copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepeatReturnCheckChangeProofCard(
              proof: _proofForChoice(RepeatReturnCheckChoice.softer),
              entryCount: 4,
              surface: 'patterns',
              onRecordNext: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(RepeatReturnCheckCopy.trendSofterThanBefore), findsOneWidget);
    });

    testWidgets('shows same body copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepeatReturnCheckChangeProofCard(
              proof: _proofForChoice(RepeatReturnCheckChoice.same),
              entryCount: 4,
              surface: 'patterns',
              onRecordNext: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(RepeatReturnCheckCopy.trendSteady), findsOneWidget);
    });
  });

  group('RepeatReturnCheckAnalytics change proof', () {
    test('records metadata only for proof seen', () {
      RepeatReturnCheckAnalytics.recordChangeProofSeen(
        latestChoice: RepeatReturnCheckChoice.stronger,
        entryCount: 4,
        surface: 'record',
      );
      expect(captured, hasLength(1));
      expect(captured.single.event, RepeatReturnCheckAnalytics.changeProofSeenEvent);
      expect(captured.single.properties['reason'], 'stronger');
      expect(captured.single.properties.containsKey('transcript'), isFalse);
    });
  });

  group('RepeatReturnCheckTrendEngine', () {
    test('supports future softer and louder copy', () {
      final records = [
        RepeatReturnCheckRecord(
          entryId: 'e5',
          choice: RepeatReturnCheckChoice.softer,
          entryCountAtCapture: 5,
          createdAt: DateTime(2026, 6, 14),
        ),
        RepeatReturnCheckRecord(
          entryId: 'e4',
          choice: RepeatReturnCheckChoice.same,
          entryCountAtCapture: 4,
          createdAt: DateTime(2026, 6, 13),
        ),
      ];
      expect(
        RepeatReturnCheckTrendEngine.latestTrendCopy(records),
        RepeatReturnCheckCopy.trendSofterThanBefore,
      );

      final louderRecords = [
        RepeatReturnCheckRecord(
          entryId: 'e5',
          choice: RepeatReturnCheckChoice.stronger,
          entryCountAtCapture: 5,
          createdAt: DateTime(2026, 6, 14),
        ),
        RepeatReturnCheckRecord(
          entryId: 'e4',
          choice: RepeatReturnCheckChoice.same,
          entryCountAtCapture: 4,
          createdAt: DateTime(2026, 6, 13),
        ),
      ];
      expect(
        RepeatReturnCheckTrendEngine.latestTrendCopy(louderRecords),
        RepeatReturnCheckCopy.trendGettingLouder,
      );
    });
  });

  group('RepeatReturnCheckCard', () {
    testWidgets('renders prompt and choice buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepeatReturnCheckCard.test(
              entryId: 'e4',
              entryCount: 4,
              surface: 'record',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(RepeatReturnCheckCopy.prompt), findsOneWidget);
      expect(find.text(RepeatReturnCheckCopy.stronger), findsOneWidget);
      expect(find.text(RepeatReturnCheckCopy.same), findsOneWidget);
      expect(find.text(RepeatReturnCheckCopy.softer), findsOneWidget);
    });

    testWidgets('shows saved confirmation after choice', (tester) async {
      final prefs = _MemoryPrefs();
      final store = RepeatReturnCheckStore(prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepeatReturnCheckCard(
              entryId: 'e4',
              entryCount: 4,
              surface: 'record',
              store: store,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('repeat_return_check_softer')));
      await tester.pumpAndSettle();

      expect(find.text(RepeatReturnCheckCopy.saved), findsOneWidget);
    });
  });

  group('RepeatReturnCheckAnalytics', () {
    test('records metadata only', () {
      RepeatReturnCheckAnalytics.recordChoice(
        choice: RepeatReturnCheckChoice.stronger,
        entryCount: 4,
        surface: 'record',
      );
      expect(captured, hasLength(1));
      expect(captured.single.event, RepeatReturnCheckAnalytics.choiceEvent);
      expect(captured.single.properties['reason'], 'stronger');
      expect(captured.single.properties.containsKey('transcript'), isFalse);
    });
  });
}
