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
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_analytics.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_controller.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_model.dart';
import 'package:voicememory_mobile/features/share/archive_share_actions.dart';
import 'package:voicememory_mobile/features/support/testflight_feedback_launcher.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/widgets/beta_feedback_card.dart';
import 'package:voicememory_mobile/widgets/account/beta_feedback_sheet.dart';

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
      journalStore = await JournalStore.open(
        '${tempDir.path}/journal.json',
        encryptAtRest: false,
      );
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

  group('Beta feedback v1 sheet', () {
    setUp(() async {
      await _resetServicesForAccount();
    });

    tearDown(() {
      BetaFeedbackAnalytics.resetForTest();
      TestFlightFeedbackLauncher.launchUrlForTest = null;
    });

    test('submission message excludes transcripts audio and internal IDs', () {
      const controller = BetaFeedbackController();
      final message = controller.buildMessage(
        const BetaFeedbackSubmission(
          source: 'account',
          option: BetaFeedbackOptionType.useful,
          entryCount: 4,
          appVersion: '1.2.3 (45)',
          note: 'Comparison view helped.',
        ),
      );
      expect(message, contains('Surface: account'));
      expect(message, contains('Option: Something felt useful'));
      expect(message, contains('Entry count: 4'));
      expect(message, contains('App version: 1.2.3 (45)'));
      expect(message, contains('Note:'));
      expect(message, contains('Comparison view helped.'));
      expect(message.toLowerCase(), isNot(contains('transcript')));
      expect(message.toLowerCase(), isNot(contains('audio')));
      expect(message, isNot(contains('entry-')));
      expect(message, isNot(contains('uuid')));
    });

    testWidgets('feedback link appears in Account', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('account_beta_feedback_tile')),
        200,
      );
      expect(find.text(BetaFeedbackCopy.sheetLinkLabel), findsOneWidget);
      expect(find.text(ConsumerUiCopy.accountTitle), findsOneWidget);
    });

    testWidgets('feedback sheet opens from Account', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('account_beta_feedback_tile')),
        200,
      );
      await tester.tap(find.byKey(const Key('account_beta_feedback_tile')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('beta_feedback_sheet')), findsOneWidget);
      expect(find.text(BetaFeedbackCopy.sheetTitle), findsWidgets);
      expect(find.text(BetaFeedbackCopy.sheetSubtitle), findsOneWidget);
    });

    testWidgets('all options render in sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => BetaFeedbackSheet.show(
                  context,
                  source: 'test',
                  entryCount: 2,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final option in BetaFeedbackOptionType.values) {
        expect(find.text(option.label), findsOneWidget);
      }
    });

    testWidgets('optional note field works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => BetaFeedbackSheet.show(
                  context,
                  source: 'test',
                  entryCount: 1,
                  controller: BetaFeedbackController(
                    loadAppVersion: _fixedVersion,
                    launchEmail: (_) async => false,
                    copyText: (_, __) async => ArchiveShareOutcome.copied,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beta_feedback_option_useful')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('beta_feedback_sheet_note')),
        'Helpful comparison view.',
      );
      await tester.pump();
      expect(find.text('Helpful comparison view.'), findsOneWidget);
    });

    testWidgets('analytics excludes note text', (tester) async {
      final captured = <({String event, Map<String, Object> properties})>[];
      BetaFeedbackAnalytics.captureForTest =
          (event, properties) => captured.add((event: event, properties: properties));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => BetaFeedbackSheet.show(
                  context,
                  source: 'weekly_review',
                  entryCount: 3,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final opened = captured
          .where((e) => e.event == BetaFeedbackAnalytics.openedEvent)
          .single;
      expect(opened.properties['source'], 'weekly_review');
      expect(opened.properties['entry_count'], 3);
      expect(opened.properties.containsKey('note'), isFalse);

      BetaFeedbackAnalytics.submitted(
        source: 'weekly_review',
        optionType: BetaFeedbackOptionType.wrong.analyticsKey,
        entryCount: 3,
      );

      final submitted = captured
          .where((e) => e.event == BetaFeedbackAnalytics.submittedEvent)
          .single;
      expect(submitted.properties['option_type'], 'wrong');
      final blob = submitted.properties.entries
          .map((e) => '${e.key}:${e.value}')
          .join(' ');
      expect(blob.toLowerCase(), isNot(contains('private note')));
      expect(blob.toLowerCase(), isNot(contains('note')));
    });

    testWidgets('email fallback copies feedback when launcher fails', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Uri? capturedUri;
      String? copiedText;
      final controller = BetaFeedbackController(
        loadAppVersion: _fixedVersion,
        launchEmail: (uri) async {
          capturedUri = uri;
          return false;
        },
        copyText: (_, text) async {
          copiedText = text;
          return ArchiveShareOutcome.copied;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => BetaFeedbackSheet.show(
                  context,
                  source: 'account',
                  entryCount: 5,
                  controller: controller,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beta_feedback_option_other')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('beta_feedback_sheet_note')),
        'Needs clearer next step.',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('beta_feedback_sheet_send')).last);
      await tester.tap(find.byKey(const Key('beta_feedback_sheet_send')).last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('beta_feedback_preview_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('beta_feedback_preview_send')));
      await tester.pumpAndSettle();

      expect(capturedUri, isNotNull);
      expect(capturedUri!.scheme, 'mailto');
      expect(copiedText, isNotNull);
      expect(copiedText!, contains('Surface: account'));
      expect(copiedText!, contains('Needs clearer next step.'));
      expect(copiedText!.toLowerCase(), isNot(contains('transcript')));
      expect(find.text(BetaFeedbackCopy.emailCopiedFallback), findsOneWidget);
    });

    testWidgets('preview shown before email send', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var emailLaunched = false;
      final controller = BetaFeedbackController(
        loadAppVersion: _fixedVersion,
        launchEmail: (_) async {
          emailLaunched = true;
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => BetaFeedbackSheet.show(
                  context,
                  source: 'first_proof',
                  entryCount: 3,
                  controller: controller,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('beta_feedback_option_useful')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('beta_feedback_sheet_send')).last);
      await tester.tap(find.byKey(const Key('beta_feedback_sheet_send')).last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('beta_feedback_preview_message')), findsOneWidget);
      expect(emailLaunched, isFalse);
      await tester.tap(find.byKey(const Key('beta_feedback_preview_send')));
      await tester.pumpAndSettle();
      expect(emailLaunched, isTrue);
    });
  });
}

Future<String> _fixedVersion() async => '9.9.9 (99)';

Future<void> _resetServicesForAccount() async {
  final stamp = DateTime.now().microsecondsSinceEpoch.toString();
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_beta_feedback_journal_$stamp.json',
    prefsPath: '/tmp/vm_beta_feedback_prefs_$stamp.json',
  );
}
