import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_export/archive_export_pack.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_copy.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_engine.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_gates.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_store.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta_feedback_card.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
  'pro is active',
  'locked',
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Start trial',
  'Limited time',
];

JournalEntry _entry(
  String id, {
  String? transcript,
}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript: transcript ??
          'I felt pressure at work before saying yes again even when I was tired today.',
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

List<JournalEntry> _entries(int count) => List.generate(
      count,
      (i) => _entry(
        'e$i',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired today $i.',
      ),
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

  group('Beta feedback gates', () {
    test('hidden below three real entries', () {
      for (final count in [0, 1, 2]) {
        expect(
          BetaFeedbackGates.showCard(
            realEntryCount: count,
            sampleMode: false,
            state: BetaFeedbackState.empty,
          ),
          isFalse,
          reason: 'count $count',
        );
      }
    });

    test('shown at three or more real entries', () {
      expect(
        BetaFeedbackGates.showCard(
          realEntryCount: 3,
          sampleMode: false,
          state: BetaFeedbackState.empty,
        ),
        isTrue,
      );
    });

    test('hidden in sample archive and screenshot mode', () {
      expect(
        BetaFeedbackGates.showCard(
          realEntryCount: 5,
          sampleMode: true,
          state: BetaFeedbackState.empty,
        ),
        isFalse,
      );
    });

    test('hidden when dismissed or already answered', () {
      expect(
        BetaFeedbackGates.showCard(
          realEntryCount: 5,
          sampleMode: false,
          state: const BetaFeedbackState(dismissed: true),
        ),
        isFalse,
      );
      expect(
        BetaFeedbackGates.showCard(
          realEntryCount: 5,
          sampleMode: false,
          state: const BetaFeedbackState(
            usefulness: BetaFeedbackUsefulness.useful,
          ),
        ),
        isFalse,
      );
    });
  });

  group('Beta feedback store', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late BetaFeedbackStore store;
    late JournalStore journalStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('beta_feedback_test_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      store = BetaFeedbackStore(prefs);
      journalStore = await JournalStore.open('${tempDir.path}/journal.json');
      await BetaFeedbackStore.resetForTest();
    });

    tearDown(() async {
      await BetaFeedbackStore.resetForTest();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists each feedback choice', () async {
      await store.saveResponse(usefulness: BetaFeedbackUsefulness.useful);
      expect((await store.load()).usefulness, BetaFeedbackUsefulness.useful);

      await store.saveResponse(usefulness: BetaFeedbackUsefulness.notYet);
      expect((await store.load()).usefulness, BetaFeedbackUsefulness.notYet);

      await store.saveResponse(clarity: BetaFeedbackClarity.understood);
      expect((await store.load()).clarity, BetaFeedbackClarity.understood);

      await store.saveResponse(clarity: BetaFeedbackClarity.confused);
      expect((await store.load()).clarity, BetaFeedbackClarity.confused);
    });

    test('persists usefulness, clarity, and optional note locally', () async {
      await store.saveResponse(
        usefulness: BetaFeedbackUsefulness.useful,
        clarity: BetaFeedbackClarity.understood,
        note: 'Comparison helped.',
      );

      final raw = await prefs.readMap(BetaFeedbackStore.prefsKey);
      expect(raw, isNotNull);
      expect(raw!['usefulness'], 'useful');
      expect(raw['clarity'], 'understood');
      expect(raw['note'], 'Comparison helped.');

      final loaded = await store.load();
      expect(loaded.usefulness, BetaFeedbackUsefulness.useful);
      expect(loaded.clarity, BetaFeedbackClarity.understood);
      expect(loaded.note, 'Comparison helped.');
    });

    test('user can dismiss card locally', () async {
      await store.dismiss();
      final loaded = await store.load();
      expect(loaded.dismissed, isTrue);
    });

    test('dismiss persists without touching journal', () async {
      await journalStore.save(_entry('j1'));
      final before = await journalStore.loadAll();
      await store.dismiss();
      final after = await journalStore.loadAll();
      expect(after.length, before.length);
      expect((await store.load()).dismissed, isTrue);
    });

    test('does not write journal entries or raw entry text', () async {
      await journalStore.save(_entry('j1', transcript: 'Private moment text'));
      await store.saveResponse(
        usefulness: BetaFeedbackUsefulness.notYet,
        clarity: BetaFeedbackClarity.confused,
        note: 'Still learning',
      );
      final journalRaw = await File('${tempDir.path}/journal.json').readAsString();
      final prefsRaw = await File('${tempDir.path}/prefs.json').readAsString();
      expect(journalRaw, contains('Private moment text'));
      expect(prefsRaw, isNot(contains('Private moment text')));
      expect(prefsRaw, contains('archiveBetaFeedback'));
    });
  });

  group('Beta feedback copy', () {
    test('uses ArchiveMe branding and safe language', () {
      _expectNoBannedCopy(BetaFeedbackCopy.allVisibleCopy());
      for (final text in BetaFeedbackCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        BetaFeedbackCopy.allVisibleCopy(),
        anyElement(contains('ArchiveMe')),
      );
    });

    test('testimonial helper uses safe generic copy only', () {
      final templates = [
        BetaFeedbackCopy.testimonialFor(
          const BetaFeedbackState(usefulness: BetaFeedbackUsefulness.useful),
        ),
        BetaFeedbackCopy.testimonialFor(
          const BetaFeedbackState(clarity: BetaFeedbackClarity.understood),
        ),
        BetaFeedbackCopy.testimonialFor(
          const BetaFeedbackState(usefulness: BetaFeedbackUsefulness.notYet),
        ),
      ];
      for (final text in templates) {
        expect(text, contains('ArchiveMe'));
        expect(text.toLowerCase(), isNot(contains('private')));
        expect(text.toLowerCase(), isNot(contains('transcript')));
      }
      expect(
        BetaFeedbackCopy.testimonialDefault,
        'ArchiveMe helped me notice a pattern across my own saved moments.',
      );
    });

    test('does not include Buy now or Subscribe now copy', () {
      final joined = BetaFeedbackCopy.allVisibleCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });
  });

  group('Beta feedback engine', () {
    test('real entry count excludes sample archive entries', () {
      const engine = BetaFeedbackEngine();
      final sample = SampleArchiveEntries.build();
      final mixed = [..._entries(2), ...sample.take(2)];
      expect(engine.realEntryCount(mixed), 2);
      expect(engine.realEntryCount(_entries(3)), 3);
    });

    test('summary excludes private entry text', () {
      const engine = BetaFeedbackEngine();
      final summary = engine.buildSummary(
        entries: _entries(3),
        watchThemesCount: 1,
        feedbackState: const BetaFeedbackState(
          usefulness: BetaFeedbackUsefulness.useful,
        ),
      );
      final text = BetaFeedbackCopy.buildSummaryText(summary);
      expect(summary.momentsSavedCount, 3);
      expect(text, contains('Moments saved: 3'));
      expect(text, contains(BetaFeedbackCopy.summaryNoPrivateEntries));
      expect(text, isNot(contains('felt pressure at work')));
    });
  });

  group('Beta feedback UI', () {
    testWidgets('card hidden below three entries', (tester) async {
      for (final count in [0, 1, 2]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: BetaFeedbackCard.test(
                entries: _entries(count),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('beta_feedback_card_hidden')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('card shown at three or more entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BetaFeedbackCard.test(entries: _entries(3)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('beta_feedback_card')), findsOneWidget);
      expect(find.text(BetaFeedbackCopy.cardTitle), findsOneWidget);
    });

    testWidgets('hidden in sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BetaFeedbackCard.test(
              entries: _entries(5),
              sampleMode: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('beta_feedback_card_hidden')), findsOneWidget);
    });

    testWidgets('user can select useful, not yet, understood, and confused', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BetaFeedbackCard.test(entries: _entries(3)),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('beta_feedback_useful')));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('beta_feedback_save'))).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('beta_feedback_not_yet')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('beta_feedback_understood')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('beta_feedback_confused')));
      await tester.pump();
      expect(find.byKey(const Key('beta_feedback_confused')), findsOneWidget);
    });

    testWidgets('thanks state renders after saved response', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BetaFeedbackCard.test(
              entries: _entries(3),
              initialState: const BetaFeedbackState(
                usefulness: BetaFeedbackUsefulness.useful,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('beta_feedback_card_hidden')), findsOneWidget);
    });

    testWidgets('dismissed state hides card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BetaFeedbackCard.test(
              entries: _entries(4),
              initialState: const BetaFeedbackState(dismissed: true),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('beta_feedback_card_hidden')), findsOneWidget);
    });
  });

  group('Privacy boundaries', () {
    test('export pack excludes beta feedback copy', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _entries(5),
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains(BetaFeedbackCopy.cardTitle)));
      expect(pack.plainText, isNot(contains('archiveBetaFeedback')));
    });

    test('share-safe proof excludes beta feedback copy', () {
      final proof = const ShareableArchiveProofEngine()
          .buildFromJournal(entries: _entries(5));
      expect(proof.shareText, isNot(contains(BetaFeedbackCopy.cardTitle)));
      expect(proof.shareText, isNot(contains('Beta feedback')));
    });

    test('beta feedback route is sensitive and wired on archive home', () {
      expect(SensitiveRoutes.isSensitiveRoute('/beta-feedback'), isTrue);
      final src = File('lib/router/app_router.dart').readAsStringSync();
      expect(src, contains("path: '/beta-feedback'"));
      final belief =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      expect(belief, contains('ArchiveHomeSectionId.betaFeedback'));
      expect(belief, contains('BetaFeedbackCard'));
    });
  });
}
