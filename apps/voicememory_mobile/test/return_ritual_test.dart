import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_export/archive_export_pack.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/return_ritual/return_ritual_copy.dart';
import 'package:voicememory_mobile/features/return_ritual/return_ritual_gates.dart';
import 'package:voicememory_mobile/features/return_ritual/return_ritual_models.dart';
import 'package:voicememory_mobile/features/return_ritual/return_ritual_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/return_ritual_card.dart';

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

const _unsetChoice = ReturnRitualChoice(presetId: '');

JournalEntry _entry(String id) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      'I felt pressure at work before saying yes again even when I was tired.',
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
  syncStatus: SyncStatus.localOnly,
);

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Return ritual copy', () {
    test('uses ArchiveMe branding and avoids banned language', () {
      const visible = [
        ReturnRitualCopy.chooseTitle,
        ReturnRitualCopy.chooseBody,
        ReturnRitualCopy.savedTitle,
        ReturnRitualCopy.savedBodyDefault,
        ReturnRitualCopy.savedBodyBeliefFits,
        ReturnRitualCopy.savedBodyWeeklyReview,
        ReturnRitualCopy.privacyLine,
        ReturnRitualCopy.changeButton,
        ReturnRitualCopy.addMomentButton,
        ReturnRitualCopy.clearButton,
        ReturnRitualCopy.customPhraseButton,
      ];
      _expectNoBannedCopy(visible);
      for (final text in visible) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
      expect(ReturnRitualCopy.chooseBody, contains('ArchiveMe'));
      expect(ReturnRitualCopy.presets, hasLength(5));
    });

    test('adapts saved body copy by entry count', () {
      expect(
        ReturnRitualCopy.savedBodyForEntryCount(1),
        ReturnRitualCopy.savedBodyDefault,
      );
      expect(
        ReturnRitualCopy.savedBodyForEntryCount(3),
        ReturnRitualCopy.savedBodyBeliefFits,
      );
      expect(
        ReturnRitualCopy.savedBodyForEntryCount(5),
        ReturnRitualCopy.savedBodyWeeklyReview,
      );
    });
  });

  group('Return ritual gates', () {
    test('hidden at 0 entries, shown at 1+', () {
      expect(ReturnRitualGates.showOnArchive(entryCount: 0), isFalse);
      expect(ReturnRitualGates.showOnArchive(entryCount: 1), isTrue);
      expect(
        ReturnRitualGates.showOnRecord(
          loaded: true,
          entryCount: 0,
          isPostSave: false,
          isReadyOrIdle: true,
        ),
        isFalse,
      );
      expect(
        ReturnRitualGates.showOnRecord(
          loaded: true,
          entryCount: 1,
          isPostSave: false,
          isReadyOrIdle: true,
        ),
        isTrue,
      );
      expect(
        ReturnRitualGates.showOnRecord(
          loaded: true,
          entryCount: 2,
          isPostSave: true,
          isReadyOrIdle: true,
        ),
        isFalse,
      );
    });
  });

  group('Return ritual store', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late ReturnRitualStore store;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('return_ritual_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      store = ReturnRitualStore(prefs);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('persists preset ritual locally', () async {
      final choice = ReturnRitualChoice(
        presetId: ReturnRitualCopy.presetEndWorkday.id,
      );
      await store.save(choice);
      final loaded = await store.load();
      expect(loaded?.presetId, ReturnRitualCopy.presetEndWorkday.id);
      expect(
        loaded?.resolvePhrase(ReturnRitualCopy.presets),
        ReturnRitualCopy.presetEndWorkday.phrase,
      );
    });

    test('persists custom phrase locally', () async {
      final choice = ReturnRitualChoice(
        presetId: ReturnRitualChoice.customPresetId,
        customPhrase: 'When Sunday planning feels heavy',
      );
      await store.save(choice);
      final loaded = await store.load();
      expect(
        loaded?.resolvePhrase(ReturnRitualCopy.presets),
        'When Sunday planning feels heavy',
      );
    });

    test('clear removes saved ritual', () async {
      await store.save(
        ReturnRitualChoice(presetId: ReturnRitualCopy.presetSameThought.id),
      );
      await store.clear();
      expect(await store.load(), isNull);
    });

    test('does not write to JournalStore', () async {
      final journal = await JournalStore.open('${tempDir.path}/entries.json');
      final before = await journal.file.readAsString();

      await store.save(
        ReturnRitualChoice(presetId: ReturnRitualCopy.presetUnclearDecision.id),
      );

      final after = await journal.file.readAsString();
      expect(after, before);
      expect((await journal.loadAll()).length, 0);
    });
  });

  group('Return ritual isolation', () {
    test('not included in share-safe proof or export pack', () {
      final entries = List.generate(5, (i) => _entry('e$i'));
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: entries,
      );
      final pack = ArchiveExportPackEngine.build(entries: entries);

      for (final phrase in ReturnRitualCopy.presets.map((p) => p.phrase)) {
        if (proof.hasProof) {
          expect(proof.shareText, isNot(contains(phrase)));
        }
        expect(pack.plainText, isNot(contains(phrase)));
      }
      expect(pack.plainText, isNot(contains(ReturnRitualCopy.chooseTitle)));
    });
  });

  group('Return ritual UI', () {
    late Directory tempDir;
    late ReturnRitualStore store;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('return_ritual_ui_');
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      store = ReturnRitualStore(prefs);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Future<void> pumpCard(
      WidgetTester tester, {
      required int entryCount,
      ReturnRitualChoice? initialChoice,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ReturnRitualCard.test(
              entryCount: entryCount,
              initialChoice: initialChoice ?? _unsetChoice,
              store: store,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('hidden at zero entries', (tester) async {
      await pumpCard(tester, entryCount: 0);
      expect(
        find.byKey(const Key('return_ritual_card_hidden')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('return_ritual_card')), findsNothing);
    });

    testWidgets('shown at one or more entries with choose state', (
      tester,
    ) async {
      await pumpCard(tester, entryCount: 1, initialChoice: _unsetChoice);
      expect(find.byKey(const Key('return_ritual_card')), findsOneWidget);
      expect(find.text(ReturnRitualCopy.chooseTitle), findsOneWidget);
      expect(
        find.text(ReturnRitualCopy.presetEndWorkday.phrase),
        findsOneWidget,
      );
    });

    testWidgets('select preset shows saved phrase', (tester) async {
      await pumpCard(tester, entryCount: 2, initialChoice: _unsetChoice);
      await tester.tap(
        find.byKey(
          Key('return_ritual_option_${ReturnRitualCopy.presetEndWorkday.id}'),
        ),
      );
      await tester.pump();

      expect(find.text(ReturnRitualCopy.savedTitle), findsOneWidget);
      expect(
        find.text(
          ReturnRitualCopy.savedComeBackLine(
            ReturnRitualCopy.presetEndWorkday.phrase,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(ReturnRitualCopy.savedBodyDefault), findsOneWidget);
    });

    testWidgets('three or more entries show belief-fit copy', (tester) async {
      await pumpCard(
        tester,
        entryCount: 3,
        initialChoice: ReturnRitualChoice(
          presetId: ReturnRitualCopy.presetSameThought.id,
        ),
      );
      expect(find.text(ReturnRitualCopy.savedBodyBeliefFits), findsOneWidget);
    });

    testWidgets('five or more entries show weekly review copy', (tester) async {
      await pumpCard(
        tester,
        entryCount: 5,
        initialChoice: ReturnRitualChoice(
          presetId: ReturnRitualCopy.presetBeforeSleep.id,
        ),
      );
      expect(find.text(ReturnRitualCopy.savedBodyWeeklyReview), findsOneWidget);
    });

    testWidgets('user can change ritual', (tester) async {
      await pumpCard(
        tester,
        entryCount: 2,
        initialChoice: ReturnRitualChoice(
          presetId: ReturnRitualCopy.presetBeforeSleep.id,
        ),
      );
      await tester.tap(find.byKey(const Key('return_ritual_change_button')));
      await tester.pump();
      expect(find.text(ReturnRitualCopy.chooseTitle), findsOneWidget);
      await tester.tap(
        find.byKey(
          Key('return_ritual_option_${ReturnRitualCopy.presetLoudFeeling.id}'),
        ),
      );
      await tester.pump();
      expect(
        find.text(
          ReturnRitualCopy.savedComeBackLine(
            ReturnRitualCopy.presetLoudFeeling.phrase,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('user can clear ritual', (tester) async {
      await pumpCard(
        tester,
        entryCount: 2,
        initialChoice: ReturnRitualChoice(
          presetId: ReturnRitualCopy.presetUnclearDecision.id,
        ),
      );
      await tester.tap(find.byKey(const Key('return_ritual_clear_button')));
      await tester.pump();
      expect(find.text(ReturnRitualCopy.chooseTitle), findsOneWidget);
      await tester.runAsync(() async {
        expect(await store.load(), isNull);
      });
    });
  });
}
